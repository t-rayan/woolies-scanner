const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

// We tell the function to pull the secret key we saved in Secret Manager
exports.analyzeSheetProxy = onRequest(
  { cors: true, secrets: ["CLAUDE_KEY"] },
  async (req, res) => {
    // Handle browser preflight CORS checks
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    // Only allow POST requests containing the layout data
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    try {
      // Safely unpack the body if it arrives as a raw string or JSON object
      let body = req.body;
      if (typeof body === "string") {
        body = JSON.parse(body);
      }

      const { base64Image, prompt } = body;

      // Extract the secure key directly from the server backend environment
      const apiKey = process.env.CLAUDE_KEY;

      if (!apiKey) {
        res.status(500).json({
          error: "API Key missing in server environment variables.",
        });
        return;
      }

      // Execute the server-to-server request to Anthropic (CORS-free)
      const anthropicResponse = await fetch(
        "https://api.anthropic.com/v1/messages",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
          },
          body: JSON.stringify({
            model: "claude-3-5-sonnet-20240620",
            max_tokens: 4000,
            messages: [
              {
                role: "user",
                content: [
                  {
                    type: "image",
                    source: {
                      type: "base64",
                      media_type: "image/jpeg",
                      data: base64Image,
                    },
                  },
                  {
                    type: "text",
                    text: prompt,
                  },
                ],
              },
            ],
          }),
        },
      );

      // Pass the analysis back to your Flutter app layout grids
      const data = await anthropicResponse.json();
      res.status(anthropicResponse.status).json(data);
    } catch (error) {
      logger.error("Proxy Execution Error:", error);
      res.status(500).json({ error: error.message });
    }
  }
);