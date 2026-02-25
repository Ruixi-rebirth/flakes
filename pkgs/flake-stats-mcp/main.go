package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// --- MCP 协议模型定义 ---

type JSONRPCRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      interface{}     `json:"id,omitempty"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type JSONRPCResponse struct {
	JSONRPC string      `json:"jsonrpc"`
	ID      interface{} `json:"id"`
	Result  interface{} `json:"result,omitempty"`
	Error   interface{} `json:"error,omitempty"`
}

type Tool struct {
	Name        string      `json:"name"`
	Description string      `json:"description"`
	InputSchema interface{} `json:"inputSchema"`
}

// --- 业务逻辑：统计 Flake 信息 ---

func getFlakeSummary() (string, error) {
	hostsDir := "hosts"
	entries, err := os.ReadDir(hostsDir)
	if err != nil {
		return "", fmt.Errorf("无法读取 hosts 目录: %v", err)
	}

	var hosts []string
	for _, entry := range entries {
		if entry.IsDir() && entry.Name() != "default.nix" {
			hosts = append(hosts, entry.Name())
		}
	}

	nixFilesCount := 0
	err = filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
		if err == nil && !info.IsDir() && strings.HasSuffix(path, ".nix") {
			nixFilesCount++
		}
		return nil
	})

	return fmt.Sprintf("NixOS Flake 概览:\n- 检测到主机配置: %s\n- 项目中 Nix 文件总数: %d\n- 状态: 运行正常", 
		strings.Join(hosts, ", "), nixFilesCount), nil
}

// --- 服务器核心逻辑 ---

func main() {
	reader := bufio.NewReader(os.Stdin)

	// 循环处理来自 AI (Client) 的请求
	for {
		input, err := reader.ReadBytes('\n')
		if err == io.EOF {
			break
		}
		if err != nil {
			logError("读取输入失败: %v", err)
			continue
		}

		var req JSONRPCRequest
		if err := json.Unmarshal(input, &req); err != nil {
			logError("解析 JSON 失败: %v", err)
			continue
		}

		// 处理不同的方法
		switch req.Method {
		case "initialize":
			// 初始化握手：告知客户端服务器的功能和版本
			sendResponse(req.ID, map[string]interface{}{
				"protocolVersion": "2025-11-25",
				"capabilities": map[string]interface{}{
					"tools": map[string]interface{}{},
				},
				"serverInfo": map[string]string{
					"name":    "flake-stats-mcp",
					"version": "1.0.0",
				},
			})

		case "notifications/initialized":
			// 初始化完成通知，无需回复
			continue

		case "tools/list":
			// 返回可用的工具列表
			sendResponse(req.ID, map[string]interface{}{
				"tools": []Tool{
					{
						Name:        "get_flake_summary",
						Description: "统计并返回当前 NixOS Flake 的主机配置和文件规模信息。",
						InputSchema: map[string]interface{}{
							"type":       "object",
							"properties": map[string]interface{}{},
						},
					},
				},
			})

		case "tools/call":
			// 执行具体的工具逻辑
			var params struct {
				Name string `json:"name"`
			}
			json.Unmarshal(req.Params, &params)

			if params.Name == "get_flake_summary" {
				summary, err := getFlakeSummary()
				if err != nil {
					sendError(req.ID, -32000, err.Error())
				} else {
					sendResponse(req.ID, map[string]interface{}{
						"content": []map[string]interface{}{
							{
								"type": "text",
								"text": summary,
							},
						},
					})
				}
			} else {
				sendError(req.ID, -32601, "工具未找到")
			}

		default:
			if req.ID != nil {
				sendError(req.ID, -32601, "方法未找到")
			}
		}
	}
}

// --- 辅助函数 ---

func sendResponse(id interface{}, result interface{}) {
	resp := JSONRPCResponse{
		JSONRPC: "2.0",
		ID:      id,
		Result:  result,
	}
	b, _ := json.Marshal(resp)
	fmt.Printf("%s\n", string(b))
}

func sendError(id interface{}, code int, message string) {
	resp := JSONRPCResponse{
		JSONRPC: "2.0",
		ID:      id,
		Error: map[string]interface{}{
			"code":    code,
			"message": message,
		},
	}
	b, _ := json.Marshal(resp)
	fmt.Printf("%s\n", string(b))
}

func logError(format string, v ...interface{}) {
	// MCP 协议中，Stdout 用于通讯，报错必须输出到 Stderr
	fmt.Fprintf(os.Stderr, format+"\n", v...)
}
