export default function handler(request, response) {
  const allowedOrigin = process.env.APP_ORIGIN || "*";
  response.setHeader("Access-Control-Allow-Origin", allowedOrigin);
  response.setHeader("Cache-Control", "no-store");
  response.status(200).json({
    url: process.env.SUPABASE_URL || "",
    key: process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY || ""
  });
}
