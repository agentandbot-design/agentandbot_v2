#!/usr/bin/env python3
"""agent_ecosystem_catalog.md içeriğini AgentAndBot ecosystem API'sine yükler."""
import json
import urllib.request

API = "https://agentandbot.com/api/ecosystem"

# (name, url, category, priority, notes)
ENTRIES = [
    # Protokoller ve iletişim
    ("MCP: Model Context Protocol spec", "https://modelcontextprotocol.io/specification/latest", "protocols", "P0", "Ana protokol standardımız"),
    ("MCP roadmap", "https://modelcontextprotocol.io/development/roadmap", "protocols", "P0", ""),
    ("MCP blog", "https://blog.modelcontextprotocol.io/", "protocols", "P1", ""),
    ("MCP GitHub", "https://github.com/modelcontextprotocol/modelcontextprotocol", "protocols", "P0", "Watch: Releases + Discussions"),
    ("A2A spec", "https://a2a-protocol.org/latest/specification/", "protocols", "P0", "Agent-to-agent"),
    ("A2A/MCP comparison", "https://a2a-protocol.org/latest/topics/a2a-and-mcp/", "protocols", "P1", ""),
    ("A2A GitHub", "https://github.com/a2aproject/A2A", "protocols", "P0", "Watch: Releases"),
    ("A2A releases", "https://github.com/a2aproject/A2A/releases", "protocols", "P1", ""),
    ("ACP GitHub", "https://github.com/i-am-bee/acp", "protocols", "P2", "A2A altında Linux Foundation'a katıldı; legacy/transition izle"),
    ("ANP GitHub", "https://github.com/agent-network-protocol/AgentNetworkProtocol", "protocols", "P2", "Emerging/decentralized agent web"),
    ("AG-UI GitHub", "https://github.com/ag-ui-protocol/ag-ui", "protocols", "P2", "Agent-user interaction, frontend event protocol"),
    ("AG-UI docs", "https://ag-ui.com/", "protocols", "P2", ""),
    # Skills
    ("Agent Skills spec", "https://agentskills.io/specification", "skills", "P0", "Skill formatımız bu standarda uygun"),
    ("Agent Skills client showcase", "https://agentskills.io/clients", "skills", "P1", ""),
    ("Anthropic skills", "https://github.com/anthropics/skills", "skills", "P0", "Referans repo"),
    ("Google skills", "https://github.com/google/skills", "skills", "P1", ""),
    ("OpenAI skills docs", "https://developers.openai.com/api/docs/guides/tools-skills", "skills", "P1", ""),
    # Standartlar
    ("OpenAPI", "https://spec.openapis.org/oas/latest.html", "standards", "P0", ""),
    ("JSON Schema", "https://json-schema.org/specification", "standards", "P0", ""),
    ("AsyncAPI", "https://www.asyncapi.com/docs/reference/specification/latest", "standards", "P1", ""),
    ("CloudEvents", "https://cloudevents.io/", "standards", "P1", ""),
    ("OAuth 2.0 RFC", "https://datatracker.ietf.org/doc/html/rfc6749", "standards", "P0", ""),
    ("OpenID Connect", "https://openid.net/specs/openid-connect-core-1_0.html", "standards", "P1", ""),
    ("W3C DID Core", "https://www.w3.org/TR/did-core/", "standards", "P2", "Decentralized identity"),
    ("WebAuthn", "https://www.w3.org/TR/webauthn-3/", "standards", "P2", ""),
    ("JSON-RPC", "https://www.jsonrpc.org/specification", "standards", "P1", "MCP transport tabanı"),
    # Providers
    ("OpenAI Responses API", "https://platform.openai.com/docs/api-reference/responses", "providers", "P0", ""),
    ("Anthropic API", "https://docs.anthropic.com/en/api", "providers", "P0", ""),
    ("Google Gemini API", "https://ai.google.dev/api", "providers", "P0", ""),
    ("Google ADK", "https://google.github.io/adk-docs/", "providers", "P1", ""),
    ("OpenAI Agents SDK", "https://openai.github.io/openai-agents-python/", "providers", "P1", ""),
    ("Anthropic Agent SDK", "https://github.com/anthropics/claude-agent-sdk-python", "providers", "P1", ""),
    ("Microsoft Agent Framework", "https://github.com/microsoft/agent-framework", "providers", "P1", ""),
    ("AWS Strands", "https://github.com/strands-agents/sdk-python", "providers", "P2", ""),
    ("LangGraph", "https://langchain-ai.github.io/langgraph/", "providers", "P1", ""),
    ("CrewAI", "https://docs.crewai.com/", "providers", "P2", ""),
    ("AutoGen/AG2", "https://microsoft.github.io/autogen/", "providers", "P2", ""),
    ("LlamaIndex", "https://docs.llamaindex.ai/", "providers", "P2", ""),
    ("PydanticAI", "https://ai.pydantic.dev/", "providers", "P2", ""),
    ("Mastra", "https://mastra.ai/docs", "providers", "P2", ""),
    ("Semantic Kernel", "https://learn.microsoft.com/en-us/semantic-kernel/", "providers", "P2", ""),
    ("Haystack", "https://docs.haystack.deepset.ai/", "providers", "P2", ""),
    # UI
    ("AG-UI (UI)", "https://ag-ui.com/", "ui", "P2", "Frontend event protocol"),
    ("MCP Apps", "https://modelcontextprotocol.io/docs/extensions/apps", "ui", "P1", ""),
    ("A2UI", "https://github.com/google/A2UI", "ui", "P2", "Emerging"),
    ("BrowserGym", "https://github.com/ServiceNow/BrowserGym", "ui", "P2", ""),
    ("WebArena", "https://webarena.dev/", "ui", "P2", ""),
    ("Playwright", "https://playwright.dev/", "ui", "P1", "Browser automation"),
    ("WebDriver BiDi", "https://w3c.github.io/webdriver-bidi/", "ui", "P2", ""),
    # Observability
    ("OpenTelemetry GenAI semantic conventions", "https://github.com/open-telemetry/semantic-conventions-genai", "observability", "P0", "Trace standardımız"),
    ("OpenTelemetry AI observability blog", "https://opentelemetry.io/blog/2025/ai-agent-observability/", "observability", "P1", ""),
    ("OpenInference", "https://github.com/Arize-ai/openinference", "observability", "P1", ""),
    ("OpenLLMetry", "https://github.com/traceloop/openllmetry", "observability", "P1", ""),
    ("W3C Trace Context", "https://www.w3.org/TR/trace-context/", "observability", "P1", ""),
    ("OpenTelemetry", "https://opentelemetry.io/", "observability", "P0", ""),
    # Evaluation
    ("Inspect AI", "https://inspect.aisi.org.uk/", "evaluation", "P1", ""),
    ("Inspect Evals", "https://ukgovernmentbeis.github.io/inspect_evals/", "evaluation", "P1", ""),
    ("Stanford HELM", "https://crfm.stanford.edu/helm/", "evaluation", "P2", ""),
    ("OpenAI Evals", "https://github.com/openai/evals", "evaluation", "P2", ""),
    ("GAIA benchmark", "https://huggingface.co/gaia-benchmark", "evaluation", "P2", ""),
    ("AgentBench", "https://github.com/THUDM/AgentBench", "evaluation", "P2", ""),
    ("SWE-bench", "https://www.swebench.com/", "evaluation", "P1", ""),
    ("τ-bench", "https://github.com/sierra-research/tau-bench", "evaluation", "P2", ""),
    ("DeepEval", "https://github.com/confident-ai/deepeval", "evaluation", "P2", ""),
    ("MLflow GenAI evaluation", "https://mlflow.org/docs/latest/genai/eval-monitor/", "evaluation", "P2", ""),
    # Security
    ("OWASP GenAI", "https://genai.owasp.org/", "security", "P0", "Sunucu hack geçmişi nedeniyle kritik"),
    ("OWASP AI Agent Security Cheat Sheet", "https://cheatsheetseries.owasp.org/cheatsheets/AI_Agent_Security_Cheat_Sheet.html", "security", "P0", ""),
    ("OWASP LLM Top 10", "https://owasp.org/www-project-top-10-for-large-language-model-applications/", "security", "P0", ""),
    ("NIST AI RMF", "https://www.nist.gov/itl/ai-risk-management-framework", "security", "P1", ""),
    ("NIST AI RMF Playbook", "https://airc.nist.gov/airmf-resources/playbook/", "security", "P1", ""),
    ("MITRE ATLAS", "https://atlas.mitre.org/", "security", "P1", ""),
    ("MITRE ATLAS GitHub", "https://github.com/mitre-atlas/atlas", "security", "P2", ""),
    ("ISO/IEC 42001 overview", "https://www.iso.org/standard/81230.html", "security", "P2", ""),
    ("ISO/IEC 23894 AI risk management", "https://www.iso.org/standard/77304.html", "security", "P2", ""),
    ("SLSA supply-chain security", "https://slsa.dev/", "security", "P1", ""),
    ("Sigstore", "https://www.sigstore.dev/", "security", "P2", ""),
    ("OpenSSF", "https://openssf.org/", "security", "P2", ""),
]


def main():
    payload = [
        {
            "name": name,
            "url": url,
            "category": cat,
            "priority": prio,
            "notes": notes,
            "added_by": "human",
        }
        for (name, url, cat, prio, notes) in ENTRIES
    ]

    req = urllib.request.Request(
        API,
        data=json.dumps({"entries": payload}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        result = json.loads(resp.read())
    print(f"ok: {result['ok']}/{result['total']}")
    errors = [r for r in result.get("results", []) if r.get("status") != "ok"]
    for e in errors[:5]:
        print("ERR:", e)


if __name__ == "__main__":
    main()
