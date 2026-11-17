export default function handler(request, response) {
  if (request.method !== "GET") {
    response.setHeader("Allow", "GET");
    return response.status(405).json({ error: "Method not allowed." });
  }
  const allowedOrigin = process.env.APP_ORIGIN;
  if (allowedOrigin) response.setHeader("Access-Control-Allow-Origin", allowedOrigin);
  response.setHeader("Vary", "Origin");
  response.setHeader("Cache-Control", "no-store");
  response.status(200).json({
    url: process.env.SUPABASE_URL || "",
    key: process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY || "",
    spotifyClientId: process.env.SPOTIFY_CLIENT_ID || ""
  });
}
