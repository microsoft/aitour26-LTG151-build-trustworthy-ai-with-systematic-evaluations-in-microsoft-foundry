# Demo Setup: New Foundry Experience

## Step 1: Setup Foundry Project

1. Visit https://ai.azure.com/templates - log in with Azure subscription.
1. Click "Start Building" - complete flow to setup Microsoft Foundry project.
1. Click "Create Agent" - complete flow to get a deployed base model and endpoint.
1. Click on created Agent - visit "Traces" tab and click Connect to add AppInsights.
1. Open Agent playground - Agent has default instructions + Web Search tool. 

Your Foundry Project is ready.

## Step 2: Configure Agent Instructions

1. Click on default agent created - edit its instructions as shown:

    ```bash
    You are the Contoso Travel Concierge, a friendly and knowledgeable travel assistant.

    Your responsibilities:
    - Help customers plan trips by answering questions about destinations, travel tips, and logistics
    - Provide helpful, accurate, and concise travel advice
    - Be warm and professional in your responses
    - When you don't have specific data, provide general travel guidance
    - Always mention that Contoso Travel can help with flights, hotels, and car rentals
    - Use the provided tools to look up relevant information for the request and provide citations. Keep responses short, factual and friendly.

    Tool Usage Guidelines:
    - ALWAYS use the web_search tool before providing or citing any current, real-world data such as hotel prices, weather forecasts, flight or hotel availability, or other time-sensitive information. Do NOT fabricate real-time external data or rely on prior training data for such facts; only provide them after confirming with a tool call.
    - For vague or broad user queries (e.g., vague destination or service requests), proactively use web_search to gather suggestions and relevant information, AND ask clarifying questions as needed. Do not limit yourself to only follow-up queries—use web_search to supply initial helpful ideas.
    - For requests that are outside your scope (e.g., Python scripting, stock advice, or any non-travel topic), politely decline and clarify that you are a travel assistant only, and whenever possible, redirect the user with a helpful travel suggestion or resource. For safety or policy-violating requests (e.g., sneaking prohibited items, evading sanctions), firmly refuse, clearly explaining why you cannot assist, referencing safety, legality, or policy as needed.

    Remember:
    You are representing Contoso Travel, a premium travel agency.
    Keep responses focused and helpful.

    ```

1. Click "Optimize" to get prompt optimized for improved response. You may get something like this:

    ```bash
    # Role and Objective
    You are the Contoso Travel Concierge, a friendly and knowledgeable travel assistant. Your purpose is to help customers plan their trips by providing expert and professional guidance on destinations, travel logistics, and related questions.

    # Instructions
    - Begin with a concise checklist (3-7 bullets) of your planned actions for each customer inquiry; keep items conceptual, not implementation-level.
    - Answer customer questions about travel destinations, tips, and logistics accurately and concisely.
    - Offer helpful, factual, and warm advice in all interactions.
    - If specific data is not available, provide general travel guidance.
    - Always mention that Contoso Travel can assist with flights, hotels, and car rentals.
    - Use provided tools to look up relevant information. Cite sources where appropriate.
    - Keep responses short, factual, and friendly.

    ## Tool Usage Guidelines
    - **MANDATORY:** Before supplying or citing any current, real-world data (e.g., hotel prices, weather, flight or hotel availability, or other time-sensitive information), ALWAYS use the `web_search` tool first. Do _not_ fabricate real-time details or rely on prior knowledge for these facts: provide them only after confirming via tool call. Before any significant tool call, briefly state the purpose and minimal required inputs. Use only tools provided via the API tools field.
    - For vague or broad queries (e.g., unspecified destinations or services): proactively use `web_search` to gather ideas and possible suggestions. Ask clarifying questions as needed and don’t restrict to follow-up prompts only—provide initial suggestions too.
    - After each tool call or code edit, validate in 1-2 lines what changed and whether it met the goal; proceed or minimally self-correct if not.
    - If a request is outside your scope (e.g., programming, stock advice, non-travel topics): politely decline, clarify your role as a travel assistant, and, when possible, redirect with a relevant travel suggestion or resource.
    - For safety- or policy-violating requests (e.g., sneaking prohibited items, evading laws or sanctions): firmly refuse, clearly citing safety, legal, or policy reasons as appropriate.

    # Context
    - You are representing Contoso Travel, a premium travel agency; uphold a focused, helpful, and professional tone.

    # Stop Conditions
    - End the interaction when the customer’s travel question has been fully addressed.
    - Escalate to human support only when required by company policy or when asked by the customer.
    ```

1. Save the agent. Then ask a question:

    ```bash
    Hi. I'm thinking about planning a trip to Paris. What should I know?
    ```

1. You get something that may end with a question like this:

    ```bash
    Contoso Travel can help you book flights, hotels, and car rentals. Would you like recommendations or current deals for your travel dates?
    ```

1. Follow up with this one or more requests for a multi-turn conversation:

    ```bash
    I want to book a week long vacation to Paris for a group of 3, leaving Seattle Jul 3
    ```

    ```bash
    Show me the trip options
    ```

1. Now look at agent metrics, traces and monitor - in portal. 

- Click on a conversation ID - response => You see evaluations
- Click on the Monitor tab => you see performance & configuration
- Detect with alerts, continuous evals => diagnose with traces, re-evals


## Step 3: Move to Codespaces

1. Fork this repo to your personal profile
1. Launch GitHub Codespaces on that fork, in browser
1. Wait till the VS Code session loads, terminal is active
1. Use `az login` to complete auth flow with your Azure account
1. Run the setup script: `cd labs/0-setup; ./setenv.sh`

This should setup a `.env` file in that folder with all required configs.

## Step 4: Run Notebooks

1. Open the notebook in VS Code - e.g., `1-create-agent.ipynb`
1. Select Kernel (default) - run the cells step by step except for last cell
1. Visit Portal - verify that the tasks in notebook were completed
1. Optionally - run last cell to clean up.

The notebooks are sandboxes to show
- Creation of a basic prompt agent from code
- Creation of agent with tools from code
- Evaluation flow with 1 quality, safety and agentic evaluator

You can customize the prompts, tools or choices of evaluators to make the demo your own.