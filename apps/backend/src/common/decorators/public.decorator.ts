import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/**
 * Marks a route as not requiring authentication — JwtAuthGuard checks this
 * metadata and, if present, skips token validation entirely (e.g. login,
 * register, refresh).
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
