# 📊 Auditoria de Conversas - TheLions Chat

## Visão Geral

O TheLions Server armazena **todo o histórico de conversas** do chat corporativo (Openfire) em banco de dados PostgreSQL, permitindo auditoria completa para fins de compliance, segurança e gestão.

---

## 🔐 Conformidade Legal

### LGPD (Lei Geral de Proteção de Dados)

✅ **Conformidade garantida:**
- Dados armazenados na infraestrutura do próprio município
- Política de retenção configurável
- Direito ao esquecimento (exclusão de dados)
- Logs de acesso ao histórico
- Criptografia em repouso e em trânsito

### LAI (Lei de Acesso à Informação)

✅ **Transparência:**
- Histórico disponível para auditorias
- Exportação de conversas em formato aberto
- Rastreabilidade completa

---

## 📦 Estrutura do Banco de Dados

### Tabela: `ofMessageArchive`

Armazena todas as mensagens trocadas no sistema.

```sql
CREATE TABLE ofMessageArchive (
    messageID       BIGSERIAL PRIMARY KEY,
    conversationID  BIGINT NOT NULL,
    fromJID         VARCHAR(1024) NOT NULL,
    fromJIDResource VARCHAR(1024),
    toJID           VARCHAR(1024) NOT NULL,
    toJIDResource   VARCHAR(1024),
    sentDate        BIGINT NOT NULL,
    body            TEXT,
    stanza          TEXT,
    isPMforMUC      BOOLEAN DEFAULT FALSE
);
```

**Campos:**
- `messageID`: ID único da mensagem
- `conversationID`: ID da conversa (agrupa mensagens)
- `fromJID`: Remetente (ex: joao@umbauba.gov)
- `toJID`: Destinatário (ex: maria@umbauba.gov)
- `sentDate`: Data/hora (timestamp Unix)
- `body`: Conteúdo da mensagem
- `stanza`: XML completo da mensagem XMPP
- `isPMforMUC`: Se é mensagem privada em sala de grupo

---

## 🔍 Consultas SQL Úteis

### 1. Buscar Mensagens de um Usuário

```sql
SELECT 
    messageID,
    fromJID,
    toJID,
    to_timestamp(sentDate/1000) AS data_envio,
    body
FROM ofMessageArchive 
WHERE fromJID LIKE '%joao@umbauba.gov%'
ORDER BY sentDate DESC
LIMIT 100;
```

### 2. Conversa Entre Dois Usuários

```sql
SELECT 
    to_timestamp(sentDate/1000) AS data_hora,
    fromJID AS remetente,
    toJID AS destinatario,
    body AS mensagem
FROM ofMessageArchive 
WHERE (
    (fromJID LIKE '%joao@umbauba.gov%' AND toJID LIKE '%maria@umbauba.gov%')
    OR
    (fromJID LIKE '%maria@umbauba.gov%' AND toJID LIKE '%joao@umbauba.gov%')
)
ORDER BY sentDate ASC;
```

### 3. Buscar por Palavra-Chave

```sql
SELECT 
    to_timestamp(sentDate/1000) AS data_hora,
    fromJID AS remetente,
    toJID AS destinatario,
    body AS mensagem
FROM ofMessageArchive 
WHERE body ILIKE '%licitação%'
ORDER BY sentDate DESC;
```

### 4. Estatísticas de Uso

```sql
-- Total de mensagens por usuário
SELECT 
    fromJID,
    COUNT(*) AS total_mensagens
FROM ofMessageArchive 
GROUP BY fromJID
ORDER BY total_mensagens DESC;

-- Mensagens por dia
SELECT 
    DATE(to_timestamp(sentDate/1000)) AS dia,
    COUNT(*) AS total_mensagens
FROM ofMessageArchive 
GROUP BY dia
ORDER BY dia DESC;
```

### 5. Mensagens em Período Específico

```sql
SELECT 
    to_timestamp(sentDate/1000) AS data_hora,
    fromJID,
    toJID,
    body
FROM ofMessageArchive 
WHERE to_timestamp(sentDate/1000) BETWEEN '2025-01-01' AND '2025-01-31'
ORDER BY sentDate DESC;
```

---

## 🖥️ Interface Web de Auditoria

### Plugin: Monitoring Service

O Openfire possui um plugin nativo para auditoria via interface web.

**Instalação:**

1. Acessar Openfire Admin: `http://servidor:9090`
2. Login: `admin` / `senha_definida`
3. Ir em **Plugins** → **Available Plugins**
4. Instalar **Monitoring Service**

**Recursos:**
- 📊 Dashboard com estatísticas
- 🔍 Busca por usuário, data, palavra-chave
- 📥 Exportação em CSV/PDF
- 📈 Gráficos de uso
- 🕐 Histórico em tempo real

---

## 📤 Exportação de Conversas

### Script Python para Exportar

```python
#!/usr/bin/env python3
import psycopg2
import csv
from datetime import datetime

# Conexão com banco
conn = psycopg2.connect(
    host="localhost",
    database="thelions_openfire",
    user="thelions",
    password="Andre@311407"
)

cur = conn.cursor()

# Buscar conversas entre dois usuários
cur.execute("""
    SELECT 
        to_timestamp(sentDate/1000) AS data_hora,
        fromJID,
        toJID,
        body
    FROM ofMessageArchive 
    WHERE (
        (fromJID LIKE %s AND toJID LIKE %s)
        OR
        (fromJID LIKE %s AND toJID LIKE %s)
    )
    ORDER BY sentDate ASC
""", ('%joao@umbauba.gov%', '%maria@umbauba.gov%', 
      '%maria@umbauba.gov%', '%joao@umbauba.gov%'))

# Exportar para CSV
with open('conversa_joao_maria.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(['Data/Hora', 'De', 'Para', 'Mensagem'])
    
    for row in cur.fetchall():
        writer.writerow(row)

print("✓ Conversa exportada para conversa_joao_maria.csv")

cur.close()
conn.close()
```

### Exportar para HTML

```python
#!/usr/bin/env python3
import psycopg2
from datetime import datetime

conn = psycopg2.connect(
    host="localhost",
    database="thelions_openfire",
    user="thelions",
    password="Andre@311407"
)

cur = conn.cursor()

cur.execute("""
    SELECT 
        to_timestamp(sentDate/1000) AS data_hora,
        fromJID,
        body
    FROM ofMessageArchive 
    WHERE (fromJID LIKE %s OR toJID LIKE %s)
    ORDER BY sentDate ASC
""", ('%joao@umbauba.gov%', '%joao@umbauba.gov%'))

html = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Histórico de Conversas - João</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .message { padding: 10px; margin: 5px 0; border-radius: 5px; }
        .sent { background: #e3f2fd; text-align: right; }
        .received { background: #f5f5f5; }
        .timestamp { font-size: 0.8em; color: #666; }
    </style>
</head>
<body>
    <h1>Histórico de Conversas - João</h1>
"""

for row in cur.fetchall():
    data_hora, remetente, mensagem = row
    classe = "sent" if "joao" in remetente.lower() else "received"
    
    html += f"""
    <div class="message {classe}">
        <div class="timestamp">{data_hora}</div>
        <div><strong>{remetente}</strong></div>
        <div>{mensagem}</div>
    </div>
    """

html += """
</body>
</html>
"""

with open('historico_joao.html', 'w', encoding='utf-8') as f:
    f.write(html)

print("✓ Histórico exportado para historico_joao.html")

cur.close()
conn.close()
```

---

## ⚙️ Configuração de Retenção

### Política de Retenção de Dados

Editar `/var/lib/openfire/conf/openfire.xml`:

```xml
<archiving>
    <!-- Habilitar arquivamento -->
    <enabled>true</enabled>
    
    <!-- Dias de retenção (0 = infinito) -->
    <maxAge>365</maxAge>
    
    <!-- Tamanho máximo do arquivo (MB) -->
    <maxSize>10000</maxSize>
    
    <!-- Arquivar mensagens de salas -->
    <archiveRooms>true</archiveRooms>
</archiving>
```

### Limpeza Automática (Cron)

```bash
#!/bin/bash
# /etc/cron.daily/cleanup-chat-history.sh

# Deletar mensagens com mais de 1 ano
psql -U thelions -d thelions_openfire << EOF
DELETE FROM ofMessageArchive 
WHERE to_timestamp(sentDate/1000) < NOW() - INTERVAL '1 year';
EOF

echo "$(date): Histórico de chat limpo (>1 ano)" >> /var/log/thelions/cleanup.log
```

---

## 🔒 Segurança e Privacidade

### Controle de Acesso

Apenas administradores autorizados devem ter acesso ao banco de dados:

```sql
-- Criar usuário somente leitura para auditoria
CREATE USER auditor WITH PASSWORD 'senha_forte';
GRANT SELECT ON ofMessageArchive TO auditor;
```

### Criptografia

- ✅ **Em trânsito:** TLS/SSL nas conexões XMPP
- ✅ **Em repouso:** Criptografia de disco (LUKS)
- ✅ **Backup:** Backups criptografados com GPG

### Logs de Auditoria

Registrar quem acessou o histórico:

```sql
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    usuario VARCHAR(255),
    acao VARCHAR(255),
    data_hora TIMESTAMP DEFAULT NOW(),
    detalhes TEXT
);

-- Trigger para registrar acessos
CREATE OR REPLACE FUNCTION log_audit()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log (usuario, acao, detalhes)
    VALUES (current_user, TG_OP, 'Acesso ao histórico de mensagens');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_message_access
AFTER SELECT ON ofMessageArchive
FOR EACH STATEMENT
EXECUTE FUNCTION log_audit();
```

---

## 📋 Casos de Uso

### 1. Auditoria de Compliance

**Cenário:** Tribunal de Contas solicita histórico de conversas sobre licitação X.

**Solução:**
```sql
SELECT * FROM ofMessageArchive 
WHERE body ILIKE '%licitação 001/2025%'
ORDER BY sentDate;
```

Exportar para PDF e enviar ao TCE.

### 2. Investigação Interna

**Cenário:** RH precisa investigar denúncia de assédio.

**Solução:**
```sql
SELECT * FROM ofMessageArchive 
WHERE (fromJID = 'suspeito@umbauba.gov' OR toJID = 'suspeito@umbauba.gov')
AND to_timestamp(sentDate/1000) BETWEEN '2025-01-01' AND '2025-01-31';
```

### 3. Base de Conhecimento

**Cenário:** Converter conversas de suporte em artigos da base de conhecimento.

**Solução:**
1. Buscar conversas na sala "Suporte TI"
2. Identificar soluções bem-sucedidas
3. Criar artigos no GLPI baseados nas conversas

---

## 🚨 Alertas Automáticos

### Monitorar Palavras-Chave Sensíveis

```python
#!/usr/bin/env python3
import psycopg2
import smtplib
from email.mime.text import MIMEText

PALAVRAS_SUSPEITAS = ['senha', 'propina', 'fraude', 'ilegal']

conn = psycopg2.connect(
    host="localhost",
    database="thelions_openfire",
    user="thelions",
    password="Andre@311407"
)

cur = conn.cursor()

for palavra in PALAVRAS_SUSPEITAS:
    cur.execute("""
        SELECT fromJID, toJID, body, to_timestamp(sentDate/1000)
        FROM ofMessageArchive 
        WHERE body ILIKE %s
        AND to_timestamp(sentDate/1000) > NOW() - INTERVAL '24 hours'
    """, (f'%{palavra}%',))
    
    resultados = cur.fetchall()
    
    if resultados:
        # Enviar alerta por email
        msg = MIMEText(f"Detectadas {len(resultados)} mensagens com a palavra '{palavra}'")
        msg['Subject'] = f'[ALERTA] Palavra suspeita detectada: {palavra}'
        msg['From'] = 'auditoria@umbauba.gov'
        msg['To'] = 'seguranca@umbauba.gov'
        
        # Enviar email (configurar SMTP)
        # smtp.sendmail(...)
        
        print(f"⚠️  Alerta: {len(resultados)} mensagens com '{palavra}'")

cur.close()
conn.close()
```

---

## 📊 Relatórios Gerenciais

### Dashboard de Estatísticas

```sql
-- Usuários mais ativos (últimos 30 dias)
SELECT 
    fromJID,
    COUNT(*) AS mensagens_enviadas
FROM ofMessageArchive 
WHERE to_timestamp(sentDate/1000) > NOW() - INTERVAL '30 days'
GROUP BY fromJID
ORDER BY mensagens_enviadas DESC
LIMIT 10;

-- Horários de pico
SELECT 
    EXTRACT(HOUR FROM to_timestamp(sentDate/1000)) AS hora,
    COUNT(*) AS total_mensagens
FROM ofMessageArchive 
WHERE to_timestamp(sentDate/1000) > NOW() - INTERVAL '7 days'
GROUP BY hora
ORDER BY hora;

-- Taxa de adoção
SELECT 
    COUNT(DISTINCT fromJID) AS usuarios_ativos,
    (SELECT COUNT(*) FROM ofUser) AS total_usuarios,
    ROUND(100.0 * COUNT(DISTINCT fromJID) / (SELECT COUNT(*) FROM ofUser), 2) AS taxa_adocao
FROM ofMessageArchive 
WHERE to_timestamp(sentDate/1000) > NOW() - INTERVAL '30 days';
```

---

## 🔗 Integração com GLPI

### Criar Ticket a partir de Conversa

```python
#!/usr/bin/env python3
import requests
import psycopg2

# Buscar conversa específica
conn = psycopg2.connect(...)
cur = conn.cursor()

cur.execute("""
    SELECT body FROM ofMessageArchive 
    WHERE conversationID = %s
    ORDER BY sentDate
""", (12345,))

mensagens = [row[0] for row in cur.fetchall()]
descricao = "\n".join(mensagens)

# Criar ticket no GLPI via API
glpi_api = "http://localhost:8080/glpi/apirest.php"
headers = {
    "Content-Type": "application/json",
    "App-Token": "TOKEN_GLPI",
    "Session-Token": "SESSION_TOKEN"
}

ticket_data = {
    "input": {
        "name": "Problema reportado via chat",
        "content": descricao,
        "urgency": 3,
        "impact": 3,
        "priority": 3
    }
}

response = requests.post(f"{glpi_api}/Ticket", json=ticket_data, headers=headers)
print(f"✓ Ticket criado: {response.json()}")
```

---

## 📚 Referências

- [Openfire Documentation](https://www.igniterealtime.org/projects/openfire/documentation.jsp)
- [XMPP Standards](https://xmpp.org/rfcs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [LGPD - Lei 13.709/2018](http://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)

---

**Desenvolvido por The Lions Informática** 🦁  
**Auditoria Completa | Compliance | Segurança**
