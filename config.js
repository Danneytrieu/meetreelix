/* meetReelix — Supabase connection.
 *
 * Both values below are PUBLIC by design. The anon key is meant to ship in
 * client code; what protects the data is the row-level security in schema.sql
 * plus the fact that event ids are 128-bit random. Never put the service_role
 * key in this file — that one bypasses every policy.
 *
 * Find these in your Supabase project under Settings → API.
 */
window.MEETREELIX_CONFIG = {
  url:     "YOUR_PROJECT_URL",   // e.g. https://abcdefghijkl.supabase.co
  anonKey: "YOUR_ANON_KEY"       // the "anon / public" key, not service_role
};
