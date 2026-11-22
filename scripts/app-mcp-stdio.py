#!/usr/bin/env python3
"""Connect a newline-delimited MCP stdio client to the running desktop app."""
import http.client
import json
import locale
import os
import sys


# The bridge can run on a different machine from the app.
_MESSAGES = {
    "en": ("Set SERVERBOX_MCP_TOKEN for this client.", "Check that ServerBox is running and the token is valid."),
    "zh": ("请为此客户端设置 SERVERBOX_MCP_TOKEN。", "请检查 ServerBox 是否运行，以及 token 是否有效。"),
    "zh-tw": ("請為此用戶端設定 SERVERBOX_MCP_TOKEN。", "請檢查 ServerBox 是否執行中，以及權杖是否有效。"),
    "de": ("SERVERBOX_MCP_TOKEN für diesen Client setzen.", "Prüfen, ob ServerBox läuft und das Token gültig ist."),
    "fr": ("Définissez SERVERBOX_MCP_TOKEN pour ce client.", "Vérifiez que ServerBox fonctionne et que le jeton est valide."),
    "es": ("Configura SERVERBOX_MCP_TOKEN para este cliente.", "Comprueba que ServerBox esté en ejecución y que el token sea válido."),
    "it": ("Imposta SERVERBOX_MCP_TOKEN per questo client.", "Verifica che ServerBox sia in esecuzione e che il token sia valido."),
    "pt": ("Defina SERVERBOX_MCP_TOKEN para este cliente.", "Verifique se o ServerBox está em execução e se o token é válido."),
    "nl": ("Stel SERVERBOX_MCP_TOKEN in voor deze client.", "Controleer of ServerBox actief is en het token geldig is."),
    "ru": ("Задайте SERVERBOX_MCP_TOKEN для этого клиента.", "Убедитесь, что ServerBox запущен и токен действителен."),
    "uk": ("Задайте SERVERBOX_MCP_TOKEN для цього клієнта.", "Перевірте, чи запущено ServerBox і чи дійсний токен."),
    "tr": ("Bu istemci için SERVERBOX_MCP_TOKEN ayarlayın.", "ServerBox’ın çalıştığını ve belirtecin geçerli olduğunu doğrulayın."),
    "az": ("Bu klient üçün SERVERBOX_MCP_TOKEN təyin edin.", "ServerBox-un işlədiyini və tokenin etibarlı olduğunu yoxlayın."),
    "fa": ("برای این کلاینت SERVERBOX_MCP_TOKEN را تنظیم کنید.", "بررسی کنید که ServerBox در حال اجرا و توکن معتبر باشد."),
    "id": ("Tetapkan SERVERBOX_MCP_TOKEN untuk klien ini.", "Pastikan ServerBox berjalan dan token valid."),
    "ja": ("このクライアントの SERVERBOX_MCP_TOKEN を設定してください。", "ServerBox が起動していてトークンが有効か確認してください。"),
    "ko": ("이 클라이언트에 SERVERBOX_MCP_TOKEN을 설정하세요.", "ServerBox가 실행 중이고 토큰이 유효한지 확인하세요."),
}


def messages():
    language = (os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES")
                or os.environ.get("LANG") or locale.getlocale()[0] or "en")
    tag = language.split(".")[0].replace("_", "-").lower()
    if tag.startswith(("zh-hant", "zh-hk", "zh-mo")):
        tag = "zh-tw"
    return _MESSAGES.get(tag, _MESSAGES.get(tag.split("-")[0], _MESSAGES["en"]))


def main():
    missing_token, connection_error = messages()
    token = os.environ.get("SERVERBOX_MCP_TOKEN")
    if not token:
        sys.exit(missing_token)
    host = os.environ.get("SERVERBOX_MCP_HOST", "127.0.0.1")
    try:
        port = int(os.environ.get("SERVERBOX_MCP_PORT", "49762"))
        if not 1 <= port <= 65535:
            raise ValueError
    except ValueError:
        sys.exit("SERVERBOX_MCP_PORT: 1–65535")
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    for line in sys.stdin.buffer:
        message = {}
        connection = http.client.HTTPConnection(host, port, timeout=55)
        try:
            message = json.loads(line)
            connection.request("POST", "/mcp", line, headers)
            response = connection.getresponse()
            body = response.read()
            if response.status == 202:
                continue
            if response.status != 200:
                raise ValueError
            reply = json.loads(body)
        except (OSError, ValueError, http.client.HTTPException):
            if not isinstance(message, dict) or "id" not in message:
                continue
            reply = {"jsonrpc": "2.0", "id": message["id"], "error": {
                "code": -32000, "message": connection_error
            }}
        finally:
            connection.close()
        print(json.dumps(reply), flush=True)


if __name__ == "__main__":
    main()
