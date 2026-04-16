## Unified Tool Reference

### get_node (Unified Node Information)

**Detail Levels** (mode="info", default):
- `minimal` (~200 tokens) - Basic metadata only
- `standard` (~1-2K tokens) - Essential properties + operations (RECOMMENDED)
- `full` (~3-8K tokens) - Complete schema (use sparingly)

**Operation Modes**:
- `info` (default) - Node schema with detail level
- `docs` - Readable markdown documentation
- `search_properties` - Find specific properties (use with propertyQuery)
- `versions` - List all versions with breaking changes
- `compare` - Compare two versions
- `breaking` - Show only breaking changes
- `migrations` - Show auto-migratable changes

```javascript
// Standard (recommended)
get_node({nodeType: "nodes-base.httpRequest"})

// Get documentation
get_node({nodeType: "nodes-base.webhook", mode: "docs"})

// Search for properties
get_node({nodeType: "nodes-base.httpRequest", mode: "search_properties", propertyQuery: "auth"})

// Check versions
get_node({nodeType: "nodes-base.executeWorkflow", mode: "versions"})
```

### validate_node (Unified Validation)

**Modes**:
- `full` (default) - Comprehensive validation with errors/warnings/suggestions
- `minimal` - Quick required fields check only

**Profiles** (for mode="full"):
- `minimal` - Very lenient
- `runtime` - Standard (default, recommended)
- `ai-friendly` - Balanced for AI workflows
- `strict` - Most thorough (production)

```javascript
// Full validation with runtime profile
validate_node({nodeType: "nodes-base.slack", config: {...}, profile: "runtime"})

// Quick required fields check
validate_node({nodeType: "nodes-base.webhook", config: {}, mode: "minimal"})
```

---

## Performance Characteristics

| Tool | Response Time | Payload Size |
|------|---------------|--------------|
| search_nodes | <20ms | Small |
| get_node (standard) | <10ms | ~1-2KB |
| get_node (full) | <100ms | 3-8KB |
| validate_node (minimal) | <50ms | Small |
| validate_node (full) | <100ms | Medium |
| validate_workflow | 100-500ms | Medium |
| n8n_create_workflow | 100-500ms | Medium |
| n8n_update_partial_workflow | 50-200ms | Small |
| n8n_deploy_template | 200-500ms | Medium |

---

