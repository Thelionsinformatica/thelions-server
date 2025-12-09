#!/bin/bash
################################################################################
# TheLions Server - Script de Instalação Automatizada
# Versão: 1.0
# Data: 09/12/2025
# Autor: Manus AI para The Lions Informática
################################################################################

set -e  # Parar em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função de log
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Banner
clear
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║   ████████╗██╗  ██╗███████╗    ██╗     ██╗ ██████╗ ███╗   ██╗ ║
║   ╚══██╔══╝██║  ██║██╔════╝    ██║     ██║██╔═══██╗████╗  ██║ ║
║      ██║   ███████║█████╗      ██║     ██║██║   ██║██╔██╗ ██║ ║
║      ██║   ██╔══██║██╔══╝      ██║     ██║██║   ██║██║╚██╗██║ ║
║      ██║   ██║  ██║███████╗    ███████╗██║╚██████╔╝██║ ╚████║ ║
║      ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ║
║                                                                ║
║              TheLions Server - Instalação Automatizada        ║
║              Plataforma Corporativa Integrada v1.0            ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF

echo ""
log "Iniciando instalação do TheLions Server..."
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    error "Este script precisa ser executado como root (use sudo)"
fi

# Verificar conectividade
log "Verificando conectividade com a internet..."
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    error "Sem conectividade com a internet. Verifique a configuração de rede."
fi
info "✓ Conectividade OK"

################################################################################
# 1. ATUALIZAÇÃO DO SISTEMA
################################################################################

log "ETAPA 1/9: Atualizando sistema operacional..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    fail2ban
info "✓ Sistema atualizado"

################################################################################
# 2. INSTALAÇÃO DO DOCKER
################################################################################

log "ETAPA 2/9: Instalando Docker e Docker Compose..."

# Remover versões antigas
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Adicionar repositório Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Adicionar usuário ao grupo docker
usermod -aG docker administrador

# Habilitar Docker
systemctl enable docker
systemctl start docker

info "✓ Docker instalado: $(docker --version)"

################################################################################
# 3. CONFIGURAÇÃO DE FIREWALL
################################################################################

log "ETAPA 3/9: Configurando firewall (UFW)..."

ufw --force enable
ufw default deny incoming
ufw default allow outgoing

# Portas essenciais
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 51820/udp comment 'WireGuard'

# Portas dos serviços
ufw allow 389/tcp comment 'LDAP'
ufw allow 636/tcp comment 'LDAPS'
ufw allow 88/tcp comment 'Kerberos'
ufw allow 5222/tcp comment 'Openfire XMPP'
ufw allow 5269/tcp comment 'Openfire S2S'
ufw allow 9090/tcp comment 'Openfire Admin'

info "✓ Firewall configurado"

################################################################################
# 4. INSTALAÇÃO DO WIREGUARD
################################################################################

log "ETAPA 4/9: Instalando WireGuard..."

apt-get install -y -qq wireguard wireguard-tools

# Criar diretório de configuração
mkdir -p /etc/wireguard

# Gerar chaves
wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
chmod 600 /etc/wireguard/privatekey

PRIVATE_KEY=$(cat /etc/wireguard/privatekey)
PUBLIC_KEY=$(cat /etc/wireguard/publickey)

# Criar configuração básica (será ajustada depois)
cat > /etc/wireguard/wg0.conf << WGCONF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.0.0.2/24
ListenPort = 51820

# [Peer] - Configurar depois com a chave pública do SRVPMU01
# PublicKey = <CHAVE_PUBLICA_SRVPMU01>
# AllowedIPs = 192.168.1.0/24
# Endpoint = <IP_PUBLICO_PMU>:51820
# PersistentKeepalive = 25
WGCONF

chmod 600 /etc/wireguard/wg0.conf

info "✓ WireGuard instalado"
info "  Chave Pública: $PUBLIC_KEY"
warning "  Configure o peer do SRVPMU01 em /etc/wireguard/wg0.conf"

################################################################################
# 5. PREPARAÇÃO DE DIRETÓRIOS
################################################################################

log "ETAPA 5/9: Criando estrutura de diretórios..."

mkdir -p /opt/thelions/{samba,openfire,glpi,postgresql,nginx,portal}
mkdir -p /opt/thelions/data/{ad,chat,helpdesk,files}
mkdir -p /var/log/thelions

chown -R administrador:administrador /opt/thelions
chmod -R 755 /opt/thelions

info "✓ Estrutura de diretórios criada"

################################################################################
# 6. INSTALAÇÃO DO SAMBA 4 AD
################################################################################

log "ETAPA 6/9: Instalando Samba 4 Active Directory..."

apt-get install -y -qq \
    samba \
    smbclient \
    winbind \
    libpam-winbind \
    libnss-winbind \
    krb5-config \
    krb5-user

# Parar serviços
systemctl stop smbd nmbd winbind 2>/dev/null || true
systemctl disable smbd nmbd winbind 2>/dev/null || true

# Backup da configuração padrão
mv /etc/samba/smb.conf /etc/samba/smb.conf.bak 2>/dev/null || true

info "✓ Samba 4 instalado (provisionamento manual necessário)"
warning "  Execute: samba-tool domain provision --use-rfc2307 --interactive"

################################################################################
# 7. DOCKER COMPOSE - OPENFIRE + GLPI
################################################################################

log "ETAPA 7/9: Criando Docker Compose para serviços..."

cat > /opt/thelions/docker-compose.yml << 'DOCKERCOMPOSE'
version: '3.8'

services:
  # PostgreSQL - Banco de dados central
  postgresql:
    image: postgres:15-alpine
    container_name: thelions-postgresql
    restart: always
    environment:
      POSTGRES_PASSWORD: Andre@311407
      POSTGRES_USER: thelions
      POSTGRES_DB: thelions
    volumes:
      - /opt/thelions/data/postgresql:/var/lib/postgresql/data
    networks:
      - thelions-network
    ports:
      - "5432:5432"

  # Openfire - Servidor XMPP
  openfire:
    image: quantumobject/docker-openfire:latest
    container_name: thelions-openfire
    restart: always
    environment:
      TZ: America/Sao_Paulo
    volumes:
      - /opt/thelions/data/openfire:/var/lib/openfire
    networks:
      - thelions-network
    ports:
      - "9090:9090"   # Admin console
      - "5222:5222"   # Client connections
      - "5269:5269"   # Server to server
      - "7777:7777"   # File transfer proxy

  # GLPI - Helpdesk
  glpi:
    image: diouxx/glpi:latest
    container_name: thelions-glpi
    restart: always
    environment:
      TIMEZONE: America/Sao_Paulo
    volumes:
      - /opt/thelions/data/glpi:/var/www/html/glpi
    networks:
      - thelions-network
    ports:
      - "8080:80"

  # Nginx - Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: thelions-nginx
    restart: always
    volumes:
      - /opt/thelions/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - /opt/thelions/nginx/conf.d:/etc/nginx/conf.d:ro
      - /opt/thelions/portal:/usr/share/nginx/html:ro
    networks:
      - thelions-network
    ports:
      - "80:80"
      - "443:443"

networks:
  thelions-network:
    driver: bridge
DOCKERCOMPOSE

chown administrador:administrador /opt/thelions/docker-compose.yml

info "✓ Docker Compose configurado"

################################################################################
# 8. CONFIGURAÇÃO DO NGINX
################################################################################

log "ETAPA 8/9: Configurando Nginx..."

mkdir -p /opt/thelions/nginx/conf.d

cat > /opt/thelions/nginx/nginx.conf << 'NGINXCONF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    gzip on;

    include /etc/nginx/conf.d/*.conf;
}
NGINXCONF

cat > /opt/thelions/nginx/conf.d/default.conf << 'NGINXDEFAULT'
server {
    listen 80 default_server;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # Proxy para GLPI
    location /glpi {
        proxy_pass http://glpi:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Proxy para Openfire Admin
    location /openfire {
        proxy_pass http://openfire:9090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
NGINXDEFAULT

chown -R administrador:administrador /opt/thelions/nginx

info "✓ Nginx configurado"

################################################################################
# 9. PÁGINA INICIAL DO PORTAL
################################################################################

log "ETAPA 9/9: Criando página inicial do portal..."

cat > /opt/thelions/portal/index.html << 'HTMLPAGE'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TheLions Server - Portal Corporativo</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 60px;
            max-width: 800px;
            text-align: center;
        }
        h1 {
            color: #333;
            font-size: 3em;
            margin-bottom: 20px;
        }
        .subtitle {
            color: #666;
            font-size: 1.3em;
            margin-bottom: 40px;
        }
        .services {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-top: 40px;
        }
        .service-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 15px;
            text-decoration: none;
            transition: transform 0.3s, box-shadow 0.3s;
        }
        .service-card:hover {
            transform: translateY(-10px);
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        .service-card h3 {
            font-size: 1.5em;
            margin-bottom: 10px;
        }
        .status {
            margin-top: 40px;
            padding: 20px;
            background: #f0f0f0;
            border-radius: 10px;
        }
        .status-item {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid #ddd;
        }
        .status-item:last-child { border-bottom: none; }
        .status-ok { color: #22c55e; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🦁 TheLions Server</h1>
        <p class="subtitle">Plataforma Corporativa Integrada</p>
        
        <div class="services">
            <a href="/glpi" class="service-card">
                <h3>📋 Helpdesk</h3>
                <p>GLPI</p>
            </a>
            <a href="/openfire" class="service-card">
                <h3>💬 Chat</h3>
                <p>Openfire</p>
            </a>
            <a href="#" class="service-card">
                <h3>📁 Arquivos</h3>
                <p>File Server</p>
            </a>
            <a href="#" class="service-card">
                <h3>👥 Usuários</h3>
                <p>Active Directory</p>
            </a>
        </div>

        <div class="status">
            <h3>Status dos Serviços</h3>
            <div class="status-item">
                <span>Active Directory (Samba 4)</span>
                <span class="status-ok">⚙️ Configuração Manual</span>
            </div>
            <div class="status-item">
                <span>Openfire (Chat)</span>
                <span class="status-ok">✓ Instalado</span>
            </div>
            <div class="status-item">
                <span>GLPI (Helpdesk)</span>
                <span class="status-ok">✓ Instalado</span>
            </div>
            <div class="status-item">
                <span>WireGuard (VPN)</span>
                <span class="status-ok">⚙️ Configuração Manual</span>
            </div>
        </div>
    </div>
</body>
</html>
HTMLPAGE

chown administrador:administrador /opt/thelions/portal/index.html

info "✓ Portal criado"

################################################################################
# FINALIZAÇÃO
################################################################################

echo ""
echo "════════════════════════════════════════════════════════════════"
log "✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
echo "════════════════════════════════════════════════════════════════"
echo ""

info "📋 Próximos passos MANUAIS:"
echo ""
echo "1. CONFIGURAR SAMBA 4 AD:"
echo "   sudo samba-tool domain provision --realm=UMBAUBA.GOV --domain=UMBAUBA --server-role=dc --use-rfc2307 --interactive"
echo ""
echo "2. CONFIGURAR WIREGUARD:"
echo "   - Editar /etc/wireguard/wg0.conf com dados do SRVPMU01"
echo "   - Executar: sudo systemctl enable wg-quick@wg0"
echo "   - Executar: sudo systemctl start wg-quick@wg0"
echo ""
echo "3. INICIAR SERVIÇOS DOCKER:"
echo "   cd /opt/thelions"
echo "   sudo docker compose up -d"
echo ""
echo "4. ACESSAR SERVIÇOS:"
echo "   - Portal: http://172.31.1.11"
echo "   - GLPI: http://172.31.1.11/glpi"
echo "   - Openfire Admin: http://172.31.1.11:9090"
echo ""
echo "5. CONFIGURAR INTEGRAÇÃO LDAP:"
echo "   - Openfire: Conectar ao Samba 4 AD"
echo "   - GLPI: Conectar ao Samba 4 AD"
echo ""

info "🔑 Chave Pública WireGuard (enviar para SRVPMU01):"
echo "   $(cat /etc/wireguard/publickey)"
echo ""

warning "⚠️  Lembre-se de configurar o DNS para apontar para este servidor após o AD estar ativo!"
echo ""

log "Script finalizado. Boa sorte! 🚀"
