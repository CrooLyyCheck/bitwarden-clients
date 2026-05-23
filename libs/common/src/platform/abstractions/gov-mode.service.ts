import { Observable } from "rxjs";

import { UserId } from "../../types/guid";

/**
 * Detects whether the current environment is the Gov cloud.
 *
 * Use globalIsGovMode$ / globalIsGovMode() pre-login.
 * Use isGovMode$(userId) / isGovMode(userId) when a UserId is in scope.
 *
 * MVP infers from client-side region; PM-36520 will swap to a server check.
 */
export abstract class GovModeService {
  abstract globalIsGovMode$: Observable<boolean>;
  abstract globalIsGovMode(): Promise<boolean>;
  abstract isGovMode$(userId: UserId): Observable<boolean>;
  abstract isGovMode(userId: UserId): Promise<boolean>;
}
