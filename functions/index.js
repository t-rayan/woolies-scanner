const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

exports.analyzeSheetProxy = onRequest({cors: true}, async (req, res) => {
  // 1. Handle Preflight OPTIONS requests cleanly
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  // 2. Ensure we only accept POST data requests
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  try {
    const {base64Image, prompt, apiKey} = req.body;

    if (!apiKey) {
      res.status(400).json({error: "Missing API Key parameter."});
      return;
    }

    // 3. Server-to-server call directly to Anthropic (No CORS restrictions apply here)
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
        model: "claude-sonnet-4-6",
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
    });

    const data = await anthropicResponse.json();
    res.status(anthropicResponse.status).json(data);
  } catch (error) {
    logger.error("Proxy Execution Error:", error);
    res.status(500).json({error: error.message});
  }
});
