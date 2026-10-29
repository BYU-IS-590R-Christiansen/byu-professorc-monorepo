// Same-origin /api/ so HTTPS via Caddy (https://<eip>.sslip.io) is not mixed content.
export const environment = {
  production: true,
  apiUrl: '/api/',
};
