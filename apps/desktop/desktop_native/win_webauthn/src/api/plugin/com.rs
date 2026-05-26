//! Functions for the plugin authenticator to interact with Windows COM.
#![allow(non_snake_case)]
#![allow(non_camel_case_types)]

use std::{
    alloc,
    mem::{size_of, ManuallyDrop, MaybeUninit},
    ptr::{self, NonNull},
    sync::{Arc, OnceLock},
};

use windows::{
    core::{implement, interface, IUnknown, HRESULT},
    Win32::{
        Foundation::{E_FAIL, E_INVALIDARG, RPC_E_TOO_LATE, S_OK},
        System::Com::{
            CoInitializeEx, CoInitializeSecurity, CoRegisterClassObject, CoTaskMemAlloc,
            CoTaskMemFree, CoUninitialize, IClassFactory, IClassFactory_Impl, CLSCTX_LOCAL_SERVER,
            COINIT_APARTMENTTHREADED, EOAC_NONE, REGCLS_MULTIPLEUSE, RPC_C_AUTHN_LEVEL_DEFAULT,
            RPC_C_IMP_LEVEL_IMPERSONATE,
        },
    },
};
use windows_core::{ComObjectInterface, IInspectable, Interface};

use super::{
    PluginAuthenticator, PluginCancelOperationRequest, PluginGetAssertionRequest, PluginLockStatus,
    PluginMakeCredentialRequest,
};
use crate::{
    api::sys::plugin::{
        WEBAUTHN_PLUGIN_CANCEL_OPERATION_REQUEST, WEBAUTHN_PLUGIN_OPERATION_REQUEST,
        WEBAUTHN_PLUGIN_OPERATION_RESPONSE,
    },
    ErrorKind, WinWebAuthnError,
};

static HANDLER: OnceLock<Arc<dyn PluginAuthenticator + Send + Sync>> = OnceLock::new();

#[implement(IClassFactory)]
pub struct Factory;

impl IClassFactory_Impl for Factory_Impl {
    fn CreateInstance(
        &self,
        _outer: windows::core::Ref<IUnknown>,
        iid: *const windows::core::GUID,
        object: *mut *mut core::ffi::c_void,
    ) -> windows::core::Result<()> {
        let handler = match HANDLER.get() {
            Some(handler) => Arc::clone(handler),
            None => {
                tracing::error!(
                    "Cannot create COM class object because the plugin handler is not initialized"
                );
                return Err(E_FAIL.into());
            }
        };
        let unknown: IInspectable = PluginAuthenticatorComObject { handler }.into();
        unsafe { unknown.query(iid, object).ok() }
    }

    fn LockServer(&self, _lock: windows::core::BOOL) -> windows::core::Result<()> {
        Ok(())
    }
}

#[interface("d26bcf6f-b54c-43ff-9f06-d5bf148625f7")]
pub unsafe trait IPluginAuthenticator: windows::core::IUnknown {
    fn MakeCredential(
        &self,
        request: *const WEBAUTHN_PLUGIN_OPERATION_REQUEST,
        response: *mut WEBAUTHN_PLUGIN_OPERATION_RESPONSE,
    ) -> HRESULT;

    fn GetAssertion(
        &self,
        request: *const WEBAUTHN_PLUGIN_OPERATION_REQUEST,
        response: *mut WEBAUTHN_PLUGIN_OPERATION_RESPONSE,
    ) -> HRESULT;

    fn CancelOperation(&self, request: *const WEBAUTHN_PLUGIN_CANCEL_OPERATION_REQUEST) -> HRESULT;

    fn GetLockStatus(&self, lock_status: *mut PluginLockStatus) -> HRESULT;
}

#[implement(IPluginAuthenticator)]
struct PluginAuthenticatorComObject {
    handler: Arc<dyn PluginAuthenticator + Send + Sync>,
}

impl IPluginAuthenticator_Impl for PluginAuthenticatorComObject_Impl {
    unsafe fn MakeCredential(
        &self,
        request: *const WEBAUTHN_PLUGIN_OPERATION_REQUEST,
        response: *mut WEBAUTHN_PLUGIN_OPERATION_RESPONSE,
    ) -> HRESULT {
        tracing::debug!("MakeCredential called");
        let response = match NonNull::new(response) {
            Some(response) if response.is_aligned() => response,
            _ => return E_INVALIDARG,
        };
        let request = match request.as_ref() {
            Some(request) => request,
            None => return E_INVALIDARG,
        };

        let registration_request = match PluginMakeCredentialRequest::try_from_ptr(request) {
            Ok(request) => request,
            Err(err) => {
                tracing::error!("Could not deserialize MakeCredential request: {err}");
                return E_FAIL;
            }
        };

        match self.handler.make_credential(registration_request) {
            Ok(registration_response) => {
                match write_operation_response(&registration_response, response) {
                    Ok(()) => S_OK,
                    Err(err) => {
                        tracing::error!(
                            "Failed to write MakeCredential response to Windows: {err}"
                        );
                        E_FAIL
                    }
                }
            }
            Err(err) => {
                tracing::error!("MakeCredential failed: {err}");
                E_FAIL
            }
        }
    }

    unsafe fn GetAssertion(
        &self,
        request: *const WEBAUTHN_PLUGIN_OPERATION_REQUEST,
        response: *mut WEBAUTHN_PLUGIN_OPERATION_RESPONSE,
    ) -> HRESULT {
        tracing::debug!("GetAssertion called");
        let response = match NonNull::new(response) {
            Some(response) if response.is_aligned() => response,
            _ => return E_INVALIDARG,
        };
        let request = match request.as_ref() {
            Some(request) => request,
            None => return E_INVALIDARG,
        };

        let assertion_request = match PluginGetAssertionRequest::try_from_ptr(request) {
            Ok(request) => request,
            Err(err) => {
                tracing::error!("Could not deserialize GetAssertion request: {err}");
                return E_FAIL;
            }
        };

        match self.handler.get_assertion(assertion_request) {
            Ok(assertion_response) => match write_operation_response(&assertion_response, response)
            {
                Ok(()) => S_OK,
                Err(err) => {
                    tracing::error!("Failed to write GetAssertion response to Windows: {err}");
                    E_FAIL
                }
            },
            Err(err) => {
                tracing::error!("GetAssertion failed: {err}");
                E_FAIL
            }
        }
    }

    unsafe fn CancelOperation(
        &self,
        request: *const WEBAUTHN_PLUGIN_CANCEL_OPERATION_REQUEST,
    ) -> HRESULT {
        tracing::debug!("CancelOperation called");
        let request = match PluginCancelOperationRequest::try_from(request) {
            Ok(request) => request,
            Err(hresult) => return hresult,
        };

        match self.handler.cancel_operation(request) {
            Ok(()) => S_OK,
            Err(err) => {
                tracing::error!("CancelOperation failed: {err}");
                E_FAIL
            }
        }
    }

    unsafe fn GetLockStatus(&self, lock_status: *mut PluginLockStatus) -> HRESULT {
        tracing::debug!("GetLockStatus called");
        let Some(lock_status) = lock_status.as_mut() else {
            return E_INVALIDARG;
        };

        match self.handler.lock_status() {
            Ok(status) => {
                *lock_status = status;
                S_OK
            }
            Err(err) => {
                tracing::error!("GetLockStatus failed: {err}");
                E_FAIL
            }
        }
    }
}

fn write_operation_response(
    data: &[u8],
    response: NonNull<WEBAUTHN_PLUGIN_OPERATION_RESPONSE>,
) -> Result<(), WinWebAuthnError> {
    let len = data.len().try_into().map_err(|err| {
        WinWebAuthnError::with_cause(
            ErrorKind::Serialization,
            "Response is too long to return to OS",
            err,
        )
    })?;
    let buf = data.to_com_buffer();
    unsafe {
        response.as_ptr().write(WEBAUTHN_PLUGIN_OPERATION_RESPONSE {
            cbEncodedResponse: len,
            pbEncodedResponse: buf.as_mut_ptr(),
        });
    }
    _ = ManuallyDrop::new(buf);
    Ok(())
}

pub(super) fn register_server<T>(
    clsid: &windows::core::GUID,
    handler: T,
) -> Result<(), WinWebAuthnError>
where
    T: PluginAuthenticator + Send + Sync + 'static,
{
    HANDLER.set(Arc::new(handler)).map_err(|_| {
        WinWebAuthnError::new(
            ErrorKind::WindowsInternal,
            "Plugin handler already initialized",
        )
    })?;

    static FACTORY: windows::core::StaticComObject<Factory> = Factory.into_static();
    unsafe {
        CoRegisterClassObject(
            ptr::from_ref(clsid),
            FACTORY.as_interface_ref(),
            CLSCTX_LOCAL_SERVER,
            REGCLS_MULTIPLEUSE,
        )
    }
    .map_err(|err| {
        WinWebAuthnError::with_cause(
            ErrorKind::WindowsInternal,
            "Could not register COM class object",
            err,
        )
    })?;

    Ok(())
}

pub(super) fn initialize() -> Result<(), WinWebAuthnError> {
    unsafe { CoInitializeEx(None, COINIT_APARTMENTTHREADED) }
        .ok()
        .map_err(|err| {
            WinWebAuthnError::with_cause(
                ErrorKind::WindowsInternal,
                "Could not initialize COM library",
                err,
            )
        })?;

    match unsafe {
        CoInitializeSecurity(
            None,
            -1,
            None,
            None,
            RPC_C_AUTHN_LEVEL_DEFAULT,
            RPC_C_IMP_LEVEL_IMPERSONATE,
            None,
            EOAC_NONE,
            None,
        )
    } {
        Ok(()) => Ok(()),
        Err(err) if err.code() == RPC_E_TOO_LATE => {
            tracing::debug!("COM security is already initialized");
            Ok(())
        }
        Err(err) => Err(WinWebAuthnError::with_cause(
            ErrorKind::WindowsInternal,
            "Could not initialize COM security",
            err,
        )),
    }
}

pub(super) fn uninitialize() -> Result<(), WinWebAuthnError> {
    unsafe { CoUninitialize() };
    Ok(())
}

#[repr(transparent)]
pub(super) struct ComBuffer(NonNull<MaybeUninit<u8>>);

impl ComBuffer {
    /// Returns an COM-allocated buffer of `size`.
    fn alloc(size: usize, for_slice: bool) -> Self {
        #[expect(clippy::as_conversions)]
        {
            assert!(size <= isize::MAX as usize, "requested bad object size");
        }

        // SAFETY: Any size is valid to pass to Windows, even `0`.
        let ptr = NonNull::new(unsafe { CoTaskMemAlloc(size) }).unwrap_or_else(|| {
            // XXX: This doesn't have to be correct, just close enough for an OK OOM error.
            let layout = alloc::Layout::from_size_align(size, align_of::<u8>())
                .expect("size of u8 to always be aligned");
            alloc::handle_alloc_error(layout)
        });

        if for_slice {
            // Initialize the buffer so it can later be treated as `&mut [u8]`.
            // SAFETY: The pointer is valid and we are using a valid value for a byte-wise
            // allocation.
            unsafe { ptr.write_bytes(0, size) };
        }

        Self(ptr.cast())
    }

    pub(crate) fn as_ptr<T>(&self) -> *const T {
        self.0.cast().as_ptr()
    }

    pub(crate) fn as_mut_ptr<T>(&self) -> *mut T {
        self.0.cast().as_ptr()
    }

    pub fn into_raw<T>(self) -> *mut T {
        let this = ManuallyDrop::new(self);
        this.0.cast().as_ptr()
    }
}

impl Drop for ComBuffer {
    fn drop(&mut self) {
        let ptr = self.0.cast().as_ptr();
        unsafe {
            CoTaskMemFree(Some(ptr));
        }
    }
}

pub(super) trait ComBufferExt {
    fn to_com_buffer(&self) -> ComBuffer;
}

impl ComBufferExt for Vec<u8> {
    fn to_com_buffer(&self) -> ComBuffer {
        ComBuffer::from(&self)
    }
}

impl ComBufferExt for &[u8] {
    fn to_com_buffer(&self) -> ComBuffer {
        ComBuffer::from(self)
    }
}

impl ComBufferExt for Vec<u16> {
    fn to_com_buffer(&self) -> ComBuffer {
        self.as_slice().to_com_buffer()
    }
}

impl ComBufferExt for &[u16] {
    fn to_com_buffer(&self) -> ComBuffer {
        let byte_len = std::mem::size_of_val(*self);
        let com_buffer = ComBuffer::alloc(byte_len, false);
        // SAFETY: com_buffer.0 points to a valid COM allocation of byte_len bytes.
        // We write every byte before the buffer is read.
        unsafe {
            let dst: *mut u8 = com_buffer.0.cast().as_ptr();
            for (i, &word) in self.iter().enumerate() {
                dst.add(i * size_of::<u16>())
                    .copy_from_nonoverlapping(word.to_le_bytes().as_ptr(), size_of::<u16>());
            }
        }
        com_buffer
    }
}

impl<T: AsRef<[u8]>> From<T> for ComBuffer {
    fn from(value: T) -> Self {
        let slice = value.as_ref();
        let len = slice.len();
        let com_buffer = Self::alloc(len, true);
        // SAFETY: `ptr` points to a valid allocation that `len` matches, and we made sure
        // the bytes were initialized. Additionally, bytes have no alignment requirements.
        unsafe {
            NonNull::slice_from_raw_parts(com_buffer.0.cast::<u8>(), len)
                .as_mut()
                .copy_from_slice(slice);
        }
        com_buffer
    }
}
