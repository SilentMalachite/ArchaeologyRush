# Project Overview
Development of an archaeological excavation simulation game using Elixir, Phoenix LiveView, and Elixir Desktop.
The user is an archaeology expert with decades of excavation and research experience. The system must be built authentically based on actual domain knowledge.

# Tech Stack
* Language: Elixir 1.18+
* Web Framework: Phoenix 1.8+ (using Verified Routes, HEEx)
* UI/Frontend: Phoenix LiveView
* Desktop Integration: Elixir Desktop
* Database: Ecto / SQLite3 (for local data storage in the desktop app)
* Image Processing: vix (libvips)

# AI Agent Core Directives (CRITICAL)
To minimize the user's cognitive load and maximize development efficiency, the following rules MUST be strictly followed without exception:

1. **Conclusion First:**
   Always state the "logical conclusion" or the "overview of the proposed implementation" at the very beginning of your response. Detailed code and step-by-step explanations must follow the conclusion.

2. **Minimize Change Scope (Chunking):**
   Strictly limit the number of files modified or created in a single prompt/proposal to a **MAXIMUM of 3 files**. If broader changes are required, break down the process into smaller steps, propose them incrementally, and wait for user approval before proceeding.

3. **Visual Approach (STRICTLY NO MERMAID):**
   Actively use visual diagrams to explain structures, architectures, or state transitions. However, **you are strictly forbidden from using Mermaid syntax**. Instead, use text-based visual diagrams utilizing ASCII art, Unicode box-drawing characters, or hierarchical bullet points.

4. **Respect Domain Expertise:**
   Do not guess or invent archaeological specifications (e.g., stratigraphic superposition, artifact classification, excavation processes). For any domain-specific logic, you must consult the user (the expert) for specifications and instructions before implementation.

# Quality Assurance (QA) Standards
Generate code assuming strict, Mozilla-level quality control.

* **Test-Driven & Concurrent Implementation:** Always propose ExUnit test code alongside any logic implementation.
* **Static Analysis Compliance:** Write robust, well-typed code that passes Credo (code conventions) and Dialyxir/Dialyzer (type checking) without warnings.
* **Regression Prevention:** During bug-fixing phases, always add corresponding test cases to prevent the same bug from recurring.

# Language
The agent must reply to the user in Japanese, while adhering to the rules above.

