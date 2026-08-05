/* meetReelix — Supabase connection.
 *
 * Both values below are PUBLIC by design. The publishable key is meant to ship
 * in client code; what protects the data is the row-level security in
 * schema.sql plus the fact that event ids are 128-bit random.
 *
 * Never put the secret key here (`sb_secret_…`, or a legacy JWT whose role is
 * `service_role`). This file is downloadable by anyone who opens the site, and
 * that key bypasses every policy.
 *
 * Supabase → Settings → API.
 */
window.MEETREELIX_CONFIG = {
  url:     "https://burxvsokagtqaohyvivy.supabase.co",
  anonKey: "sb_publishable_LoeAXxiNQ7Hxe-BtRKV-lg_H1mtwc9I"
};
