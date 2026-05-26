/// User verification requirement as defined by WebAuthn spec
#[derive(Debug, Clone, Default, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum UserVerificationRequirement {
    Required,
    #[default]
    Preferred,
    Discouraged,
}

impl From<u32> for UserVerificationRequirement {
    fn from(value: u32) -> Self {
        match value {
            1 => UserVerificationRequirement::Required,
            2 => UserVerificationRequirement::Preferred,
            3 => UserVerificationRequirement::Discouraged,
            _ => UserVerificationRequirement::Preferred, // Default fallback
        }
    }
}

impl From<UserVerificationRequirement> for String {
    fn from(value: UserVerificationRequirement) -> Self {
        match value {
            UserVerificationRequirement::Required => "required".to_string(),
            UserVerificationRequirement::Preferred => "preferred".to_string(),
            UserVerificationRequirement::Discouraged => "discouraged".to_string(),
        }
    }
}
