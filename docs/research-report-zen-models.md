# Research Report: Curated Model Pool for Zen MCP Server

**Date:** July 11, 2025
**Author:** Gemini CLI

## 1. Introduction

The objective of this report is to establish a curated, expanded pool of at least 15 high-quality Large Language Models (LLMs) for use with the `zen-mcp-server`. This model library is designed to support the full spectrum of development tasks and specialized Zen tools, ensuring that for any given task—from rapid debugging to multi-agent consensus—an optimal model is available.

This selection moves beyond a "one-size-fits-all" approach, creating a diverse and powerful palette of AI capabilities tailored to our project's development process.

## 2. Model Selection Philosophy

The models in this pool were selected based on a multi-faceted evaluation process that considered:

*   **Performance Benchmarks:** Analysis of 2025 leaderboards (LMArena, SWE-Bench, HLE) to identify top performers.
*   **Specialization:** Identifying models with unique strengths in specific domains like coding, reasoning, or speed.
*   **Cost-Effectiveness:** Including models that provide a strong balance of performance and affordability for everyday tasks.
*   **Diversity of "Thinking":** Selecting models from different developers (Google, Anthropic, Mistral, xAI, etc.) to provide varied perspectives, which is crucial for tools like `consensus`.
*   **Technical Specifications:** Considering factors like context window size, which is critical for tools like `analyze` and `thinkdeep`.

The goal is to create a library that is not just powerful, but also strategically diverse.

## 3. Recommended Model Pool

Below is the recommended pool of 16 models. Each entry includes the official OpenRouter model name, suggested aliases for ease of use, its key differentiators, and its ideal alignment with Zen tools.

---

### Category: Top-Tier Reasoning & Complex Problem-Solving

*   **1. Google Gemini 2.5 Pro**
    *   **Model Name:** `google/gemini-2.5-pro`
    *   **Aliases:** `gemini-pro`, `gemini-2.5`
    *   **Differentiators:** The definitive leader on most 2025 benchmarks for reasoning and coding. Massive 1M token context window.
    *   **Zen Tool Alignment:** The default choice for any complex task. Excels with `thinkdeep`, `debug`, `codereview`, and as the primary "lead" in a `consensus` session.

*   **2. xAI Grok 4**
    *   **Model Name:** `x-ai/grok-4`
    *   **Aliases:** `grok-4`, `grok`
    *   **Differentiators:** Unmatched performance on the "Humanity's Last Exam" benchmark, indicating superior reasoning, especially with tool use.
    *   **Zen Tool Alignment:** A powerful alternative to Gemini 2.5 Pro for `thinkdeep` and `debug`. Its unique perspective makes it an excellent "second opinion" in `consensus`.

*   **3. Anthropic Claude 3.5 Sonnet**
    *   **Model Name:** `anthropic/claude-3.5-sonnet`
    *   **Aliases:** `sonnet-3.5`, `claude-sonnet`
    *   **Differentiators:** A top-tier model known for its reliability, honesty, and strong performance at a competitive price point. Excellent for enterprise-grade tasks.
    *   **Zen Tool Alignment:** A go-to for `codereview` and `refactor`. Its balanced nature makes it a perfect "neutral" or "for" voice in `consensus`.

### Category: Elite Coding & Agentic Models

*   **4. Mistral Devstral Medium**
    *   **Model Name:** `mistralai/devstral-medium`
    *   **Aliases:** `devstral-medium`, `devstral`
    *   **Differentiators:** A specialized, state-of-the-art model for software engineering, outperforming larger models on coding benchmarks (SWE-Bench).
    *   **Zen Tool Alignment:** The primary choice for `refactor` and `testgen`. Ideal for any code-heavy task where precision is paramount.

*   **5. Mistral Devstral Small 1.1**
    *   **Model Name:** `mistralai/devstral-small`
    *   **Aliases:** `devstral-small`
    *   **Differentiators:** Open-weight and highly capable, designed specifically for agentic coding workflows. Can run on a single GPU.
    *   **Zen Tool Alignment:** Excellent for automated `precommit` checks and generating boilerplate code with `testgen`.

*   **6. Morph V3 Large**
    *   **Model Name:** `morph/morph-v3-large`
    *   **Aliases:** `morph-large`, `morph`
    *   **Differentiators:** A highly specialized model for applying complex code edits with extreme precision and speed.
    *   **Zen Tool Alignment:** A powerful, targeted tool for the implementation phase of a `refactor` plan, especially for large-scale, automated changes.

### Category: High-Speed & Low-Latency

*   **7. Google Gemma 3n 2B (Free)**
    *   **Model Name:** `google/gemma-3n-e2b-it:free`
    *   **Aliases:** `gemma-free`, `gemma-3n`
    *   **Differentiators:** Extremely fast and free, making it perfect for low-latency needs.
    *   **Zen Tool Alignment:** Ideal for quick `chat` sessions, syntax checks, or as a fast first-pass in a `precommit` workflow.

*   **8. Tencent Hunyuan A13B Instruct (Free)**
    *   **Model Name:** `tencent/hunyuan-a13b-instruct:free`
    *   **Aliases:** `hunyuan-free`, `hunyuan`
    *   **Differentiators:** A free, fast, and capable MoE model with strong multi-turn reasoning.
    *   **Zen Tool Alignment:** A great choice for interactive `debug` sessions where quick back-and-forth is needed. Also a good, fast "third voice" for `consensus`.

### Category: Leading Open-Source & MoE Models

*   **9. MoonshotAI Kimi K2**
    *   **Model Name:** `moonshotai/kimi-k2`
    *   **Aliases:** `kimi`, `kimi-k2`
    *   **Differentiators:** A 1-trillion parameter MoE model with a large context window and strong agentic capabilities.
    *   **Zen Tool Alignment:** Excellent for `analyze` tasks on large codebases and for providing a unique, non-mainstream perspective in `consensus`.

*   **10. TNG DeepSeek R1T2 Chimera (Free)**
    *   **Model Name:** `tngtech/deepseek-r1t2-chimera:free`
    *   **Aliases:** `chimera-free`, `chimera`
    *   **Differentiators:** A massive 671B parameter MoE model with a huge context window, assembled from multiple strong checkpoints.
    *   **Zen Tool Alignment:** The top choice for `analyze` when dealing with extremely large files or entire repositories. Its unique architecture provides a valuable "alternative" viewpoint for `thinkdeep`.

*   **11. Cognitive Computations Dolphin Mistral 24B (Free)**
    *   **Model Name:** `cognitivecomputations/dolphin-mistral-24b-venice-edition:free`
    *   **Aliases:** `dolphin-free`, `venice-uncensored`
    *   **Differentiators:** An uncensored, instruct-tuned model that allows for maximum user control over alignment and behavior.
    *   **Zen Tool Alignment:** Useful for generating creative or unconventional ideas in `planner` or acting as a "devil's advocate" / 'against' role in a `consensus` debate to surface potential risks.

### Category: Strong, Cost-Effective All-Rounders

*   **12. OpenAI GPT-4o**
    *   **Model Name:** `openai/gpt-4o`
    *   **Aliases:** `gpt-4o`, `o4`
    *   **Differentiators:** A very strong, reliable, and well-known model from OpenAI with excellent general capabilities.
    *   **Zen Tool Alignment:** A solid choice for almost any tool. A dependable participant in `consensus` and a good baseline for `codereview`.

*   **13. Mistral Large 2**
    *   **Model Name:** `mistralai/mistral-large-2`
    *   **Aliases:** `mistral-large`, `mistral-2`
    *   **Differentiators:** Mistral's flagship model, known for its strong reasoning and multilingual capabilities.
    *   **Zen Tool Alignment:** Excellent for `analyze` and `codereview`, especially in projects with internationalization requirements.

*   **14. Google Gemini 2.5 Flash**
    *   **Model Name:** `google/gemini-2.5-flash`
    *   **Aliases:** `gemini-flash`, `flash-2.5`
    *   **Differentiators:** A cheaper, faster version of Gemini 2.5 Pro that still retains a significant portion of its power.
    *   **Zen Tool Alignment:** The default choice for tasks that need to be faster than Pro but more capable than the free models. Great for `precommit` and general `chat`.

### Category: Specialized & Vision Models

*   **15. THUDM GLM 4.1V 9B Thinking**
    *   **Model Name:** `thudm/glm-4.1v-9b-thinking`
    *   **Aliases:** `glm-4v`, `glm-vision`
    *   **Differentiators:** A state-of-the-art vision-language model with a reasoning-centric "thinking paradigm."
    *   **Zen Tool Alignment:** While most Zen tools are text-based, this model is essential for any future workflows involving images (e.g., reviewing UI mockups, analyzing diagrams in `analyze`).

*   **16. OpenAI GPT-4.1**
    *   **Model Name:** `openai/gpt-4.1`
    *   **Aliases:** `gpt-4.1`
    *   **Differentiators:** A precursor to GPT-4o with a massive 1M token context window, making it a strong choice for long-document analysis.
    *   **Zen Tool Alignment:** An excellent choice for the `analyze` tool when you need to process and understand very large amounts of text or code in a single pass.

## 4. Special Considerations for Zen Tools

*   **For `consensus`:** A strong combination would be:
    1.  **Lead:** `google/gemini-2.5-pro` (for the primary, most reasoned opinion)
    2.  **Alternative:** `x-ai/grok-4` (for a different but equally powerful perspective)
    3.  **Challenger:** `cognitivecomputations/dolphin-mistral-24b-venice-edition:free` (to surface risks and unconventional ideas)

*   **For `codereview` and `refactor`:**
    *   **Primary:** `mistralai/devstral-medium` (for its coding specialization)
    *   **Secondary:** `google/gemini-2.5-pro` or `anthropic/claude-3.5-sonnet` (for general correctness and best practices)

*   **For `analyze` on large codebases:**
    *   **Top Choice:** `tngtech/deepseek-r1t2-chimera:free` (due to its massive context and unique architecture)
    *   **Alternative:** `openai/gpt-4.1` (for its 1M token window)

## 5. Conclusion

This expanded model pool provides a robust and flexible foundation for our development workflow. By strategically selecting models from this curated list, we can enhance the effectiveness of the Zen toolset, improve the quality of our outputs, and optimize for both performance and cost. It is recommended to implement this list in the `conf/custom_models.json` file.
