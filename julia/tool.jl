using ModelContextProtocol
using JSON3
using Dates

time_tool = MCPTool(
    name = "get_time",
    description = "Get current time in specified format",
    parameters = [
        ToolParameter(
            name = "format",
            type = "string",
            description = "DateTime format string",
            required = true
        )
    ],
    handler = params -> TextContent(
        text = JSON3.write(Dict(
            "time" => Dates.format(now(), params["format"])
        ))
    )
)

server = mcp_server(
    name = "time-server",
    description = "Simple MCP server with time tool",
    tools = time_tool
)

start!(server)
