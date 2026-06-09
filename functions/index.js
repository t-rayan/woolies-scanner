const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const corsHandler = require("cors")({ origin: true }); // 👈 Native CORS handler

exports.analyzeSheetProxy = onRequest(
  { secrets: ["CLAUDE_KEY"] ,
    timeoutSeconds: 300,  // 👈 5 minutes (max for v2 is 3600)
    memory: "512MiB",     // 👈 also helps with large base64 images

  }, // Removed dynamic options wrapper
  async (req, res) => {
    // Wrap the entire execution block inside the CORS handler
    return corsHandler(req, res, async () => {
      // Handle explicit preflight exit
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      try {
        let body = req.body;
        if (typeof body === "string") {
          body = JSON.parse(body);
        }

        const { base64Image, prompt } = body;
        const apiKey = process.env.CLAUDE_KEY;

        if (!apiKey) {
          res.status(500).json({
            error: "API Key missing in server environment variables.",
          });
          return;
        }

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
              model: "claude-opus-4-6",
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

        const data = await anthropicResponse.json();
        res.status(anthropicResponse.status).json(data);
      } catch (error) {
        logger.error("Proxy Execution Error:", error);
        res.status(500).json({ error: error.message });
      }
    });
  }
);