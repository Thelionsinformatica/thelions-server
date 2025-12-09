# 🔗 Integração TheLions Server + e-Cidade

**Soluções Complementares para Gestão Municipal Completa**

---

## 📋 Visão Geral

Este documento apresenta a estratégia de integração entre o **TheLions Server** (infraestrutura de TI) e o **e-Cidade** (ERP para gestão pública), criando uma solução completa e integrada para prefeituras municipais brasileiras.

---

## 🎯 Posicionamento das Soluções

### TheLions Server - Infraestrutura de TI

**Responsabilidade:** Camada de infraestrutura e comunicação

| Módulo | Função | Benefício |
|--------|--------|-----------|
| **Active Directory** | Gerenciamento centralizado de usuários | Login único em todos os sistemas |
| **Chat Corporativo** | Comunicação instantânea | Agilidade na comunicação interna |
| **Helpdesk (GLPI)** | Suporte técnico e inventário | Gestão de TI profissional |
| **File Server** | Compartilhamento de arquivos | Colaboração e segurança |
| **VPN (WireGuard)** | Conexão entre unidades | Integração de múltiplos locais |
| **Portal Unificado** | Acesso centralizado | Experiência do usuário simplificada |

### e-Cidade - ERP para Gestão Pública

**Responsabilidade:** Processos administrativos e financeiros

| Módulo | Função | Benefício |
|--------|--------|-----------|
| **Contabilidade** | Gestão contábil pública | Conformidade legal |
| **Recursos Humanos** | Folha de pagamento | Gestão de pessoal |
| **Compras/Licitações** | Processos de compra | Transparência |
| **Tesouraria** | Gestão financeira | Controle orçamentário |
| **Educação** | Gestão escolar | Qualidade educacional |
| **Saúde** | Gestão de saúde pública | Atendimento eficiente |
| **Protocolo** | Gestão documental | Rastreabilidade |

---

## 🏗️ Arquitetura Integrada

```
┌─────────────────────────────────────────────────────────────────┐
│                    PREFEITURA MUNICIPAL                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │         CAMADA DE APRESENTAÇÃO (Portal Único)          │    │
│  │         https://intranet.municipio.gov.br              │    │
│  └────────────────────────────────────────────────────────┘    │
│                            ↓                                     │
│  ┌──────────────────────┐         ┌──────────────────────┐    │
│  │   TheLions Server    │ ←────→  │      e-Cidade        │    │
│  │  (Infraestrutura)    │   API   │   (Gestão Pública)   │    │
│  ├──────────────────────┤         ├──────────────────────┤    │
│  │ • Active Directory   │         │ • Contabilidade      │    │
│  │ • Chat Corporativo   │         │ • RH/Folha           │    │
│  │ • Helpdesk (GLPI)    │         │ • Licitações         │    │
│  │ • File Server        │         │ • Tesouraria         │    │
│  │ • VPN                │         │ • Educação/Saúde     │    │
│  └──────────────────────┘         └──────────────────────┘    │
│           ↓                                  ↓                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │         CAMADA DE DADOS (PostgreSQL)                   │    │
│  │  • Usuários  • Mensagens  • Chamados  • Documentos     │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔐 Integração 1: Single Sign-On (SSO)

### Objetivo
Permitir que usuários façam login uma única vez e acessem tanto o TheLions Server quanto o e-Cidade.

### Implementação

#### 1. Active Directory como Provedor Central

**TheLions Server** fornece o Active Directory (Samba 4) que será usado por todos os sistemas.

```
Funcionário → Login Windows (AD) → Acesso automático:
                                    ├─ TheLions Portal
                                    ├─ e-Cidade
                                    ├─ GLPI
                                    └─ Chat
```

#### 2. Configuração no e-Cidade

O e-Cidade suporta autenticação LDAP nativamente.

**Arquivo:** `e-cidade/libs/db_conn.php`

```php
<?php
// Configuração LDAP para autenticação
$LDAP_ENABLED = true;
$LDAP_SERVER = "ldap://172.31.1.11";
$LDAP_PORT = 389;
$LDAP_BASE_DN = "dc=umbauba,dc=gov";
$LDAP_BIND_DN = "cn=admin,dc=umbauba,dc=gov";
$LDAP_BIND_PASSWORD = "senha_admin";
$LDAP_USER_FILTER = "(uid=%s)";
?>
```

#### 3. Sincronização de Usuários

**Script Python para sincronizar usuários AD → e-Cidade:**

```python
#!/usr/bin/env python3
import ldap
import psycopg2

# Conectar ao Active Directory
ldap_conn = ldap.initialize("ldap://172.31.1.11")
ldap_conn.simple_bind_s("cn=admin,dc=umbauba,dc=gov", "senha")

# Buscar todos os usuários
users = ldap_conn.search_s(
    "ou=Users,dc=umbauba,dc=gov",
    ldap.SCOPE_SUBTREE,
    "(objectClass=person)"
)

# Conectar ao banco do e-Cidade
db_conn = psycopg2.connect(
    host="localhost",
    database="ecidade",
    user="ecidade",
    password="senha"
)
cursor = db_conn.cursor()

# Sincronizar usuários
for dn, attrs in users:
    username = attrs['uid'][0].decode('utf-8')
    name = attrs['cn'][0].decode('utf-8')
    email = attrs['mail'][0].decode('utf-8') if 'mail' in attrs else ''
    
    # Inserir/atualizar no e-Cidade
    cursor.execute("""
        INSERT INTO db_usuarios (login, nome, email, ativo)
        VALUES (%s, %s, %s, true)
        ON CONFLICT (login) 
        DO UPDATE SET nome = EXCLUDED.nome, email = EXCLUDED.email
    """, (username, name, email))

db_conn.commit()
print(f"✓ {len(users)} usuários sincronizados")
```

**Agendar sincronização diária:**

```bash
# /etc/cron.daily/sync-ad-ecidade.sh
0 2 * * * /usr/local/bin/sync-ad-ecidade.py
```

---

## 💬 Integração 2: Notificações do e-Cidade no Chat

### Objetivo
Enviar notificações automáticas do e-Cidade para o chat corporativo.

### Casos de Uso

| Evento no e-Cidade | Notificação no Chat |
|--------------------|---------------------|
| Empenho aprovado | Notificar secretário responsável |
| Licitação publicada | Notificar comissão de licitação |
| Folha de pagamento processada | Notificar RH |
| Documento protocolado | Notificar destinatário |

### Implementação

#### 1. Plugin e-Cidade → Openfire

**Arquivo:** `e-cidade/plugins/thelions-chat/notify.php`

```php
<?php
class TheLionsChatNotifier {
    
    private $openfire_api = "http://172.31.1.11:9090/plugins/restapi/v1";
    private $api_key = "API_KEY_OPENFIRE";
    
    public function sendNotification($user, $message) {
        $data = [
            'type' => 'chat',
            'to' => $user . '@umbauba.gov',
            'body' => $message
        ];
        
        $ch = curl_init($this->openfire_api . '/messages/users');
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: ' . $this->api_key,
            'Content-Type: application/json'
        ]);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        
        $response = curl_exec($ch);
        curl_close($ch);
        
        return json_decode($response, true);
    }
    
    public function notifyEmpenhoAprovado($empenho_id, $secretario) {
        $message = "✅ Empenho #{$empenho_id} foi aprovado!";
        return $this->sendNotification($secretario, $message);
    }
    
    public function notifyLicitacaoPublicada($licitacao_num, $comissao) {
        $message = "📢 Licitação {$licitacao_num} foi publicada!";
        foreach ($comissao as $membro) {
            $this->sendNotification($membro, $message);
        }
    }
}
?>
```

#### 2. Hooks no e-Cidade

**Arquivo:** `e-cidade/emp1_empempenho004.php` (exemplo)**

```php
<?php
// Após aprovação do empenho
if ($empenho_aprovado) {
    require_once('plugins/thelions-chat/notify.php');
    
    $notifier = new TheLionsChatNotifier();
    $notifier->notifyEmpenhoAprovado($e60_codemp, $secretario_login);
}
?>
```

---

## 📋 Integração 3: Chamados GLPI a partir do e-Cidade

### Objetivo
Permitir abertura de chamados de suporte diretamente do e-Cidade.

### Implementação

#### 1. Botão "Reportar Problema" no e-Cidade

**Arquivo:** `e-cidade/header.php`

```php
<div class="header-actions">
    <a href="#" onclick="openGLPITicket(); return false;">
        <i class="fa fa-life-ring"></i> Reportar Problema
    </a>
</div>

<script>
function openGLPITicket() {
    const currentPage = window.location.href;
    const userName = '<?php echo $nome_usuario; ?>';
    const userEmail = '<?php echo $email_usuario; ?>';
    
    // Abrir modal ou redirecionar para GLPI
    window.open(
        `http://172.31.1.11:8080/glpi/front/ticket.form.php?` +
        `name=Problema no e-Cidade&` +
        `content=Página: ${encodeURIComponent(currentPage)}`,
        'glpi_ticket',
        'width=800,height=600'
    );
}
</script>
```

#### 2. API GLPI para Criar Tickets

**Script Python:**

```python
#!/usr/bin/env python3
import requests

class GLPITicketCreator:
    
    def __init__(self):
        self.base_url = "http://172.31.1.11:8080/glpi/apirest.php"
        self.app_token = "APP_TOKEN_GLPI"
        self.user_token = "USER_TOKEN_GLPI"
        self.session_token = None
        
    def init_session(self):
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"user_token {self.user_token}",
            "App-Token": self.app_token
        }
        
        response = requests.get(
            f"{self.base_url}/initSession",
            headers=headers
        )
        
        self.session_token = response.json()['session_token']
        
    def create_ticket(self, title, description, user_email):
        headers = {
            "Content-Type": "application/json",
            "Session-Token": self.session_token,
            "App-Token": self.app_token
        }
        
        data = {
            "input": {
                "name": title,
                "content": description,
                "urgency": 3,
                "impact": 3,
                "priority": 3,
                "_users_id_requester": user_email
            }
        }
        
        response = requests.post(
            f"{self.base_url}/Ticket",
            headers=headers,
            json=data
        )
        
        return response.json()

# Uso
glpi = GLPITicketCreator()
glpi.init_session()
ticket = glpi.create_ticket(
    "Erro no e-Cidade - Empenho",
    "Não consigo aprovar empenho #12345",
    "joao@umbauba.gov"
)
print(f"Ticket criado: #{ticket['id']}")
```

---

## 📁 Integração 4: Armazenamento de Documentos

### Objetivo
Armazenar documentos do e-Cidade no File Server do TheLions.

### Implementação

#### 1. Configurar e-Cidade para usar Samba

**Arquivo:** `e-cidade/config/config.php`

```php
<?php
// Diretório de uploads (Samba share)
define('UPLOAD_DIR', '//172.31.1.11/documentos/ecidade/');
define('UPLOAD_USER', 'ecidade');
define('UPLOAD_PASS', 'senha');

// Montar share automaticamente
exec("mount -t cifs //172.31.1.11/documentos /mnt/documentos -o username=ecidade,password=senha");
?>
```

#### 2. Organização de Pastas

```
/dados/documentos/ecidade/
├── contabilidade/
│   ├── empenhos/
│   ├── liquidacoes/
│   └── pagamentos/
├── licitacoes/
│   ├── 2025/
│   └── 2024/
├── rh/
│   ├── folhas/
│   └── contratos/
└── protocolo/
    ├── entrada/
    └── saida/
```

#### 3. Backup Integrado

Documentos do e-Cidade são automaticamente incluídos no backup do TheLions Server.

---

## 📊 Integração 5: Dashboard Unificado

### Objetivo
Exibir métricas do e-Cidade no painel do TheLions Server.

### Implementação

#### 1. API REST do e-Cidade

**Criar endpoint:** `e-cidade/api/dashboard.php`

```php
<?php
header('Content-Type: application/json');

// Conectar ao banco
$conn = pg_connect("host=localhost dbname=ecidade user=ecidade password=senha");

// Estatísticas
$stats = [];

// Total de empenhos do mês
$result = pg_query($conn, "
    SELECT COUNT(*) as total 
    FROM empempenho 
    WHERE EXTRACT(MONTH FROM e60_emiss) = EXTRACT(MONTH FROM CURRENT_DATE)
");
$stats['empenhos_mes'] = pg_fetch_result($result, 0, 'total');

// Total de servidores ativos
$result = pg_query($conn, "SELECT COUNT(*) as total FROM rhpessoal WHERE rh01_ativo = 't'");
$stats['servidores_ativos'] = pg_fetch_result($result, 0, 'total');

// Licitações em andamento
$result = pg_query($conn, "SELECT COUNT(*) as total FROM liclicita WHERE l20_situacao = 1");
$stats['licitacoes_andamento'] = pg_fetch_result($result, 0, 'total');

echo json_encode($stats);
?>
```

#### 2. Consumir no TheLions Dashboard

**Frontend (React):**

```typescript
import { useEffect, useState } from 'react';

interface ECidadeStats {
  empenhos_mes: number;
  servidores_ativos: number;
  licitacoes_andamento: number;
}

export function ECidadeWidget() {
  const [stats, setStats] = useState<ECidadeStats | null>(null);
  
  useEffect(() => {
    fetch('http://ecidade.umbauba.gov/api/dashboard.php')
      .then(res => res.json())
      .then(data => setStats(data));
  }, []);
  
  if (!stats) return <div>Carregando...</div>;
  
  return (
    <div className="ecidade-widget">
      <h3>e-Cidade - Estatísticas</h3>
      <div className="stats-grid">
        <div className="stat-card">
          <span className="value">{stats.empenhos_mes}</span>
          <span className="label">Empenhos (mês)</span>
        </div>
        <div className="stat-card">
          <span className="value">{stats.servidores_ativos}</span>
          <span className="label">Servidores Ativos</span>
        </div>
        <div className="stat-card">
          <span className="value">{stats.licitacoes_andamento}</span>
          <span className="label">Licitações</span>
        </div>
      </div>
    </div>
  );
}
```

---

## 🚀 Roadmap de Implementação

### Fase 1: Fundação (Mês 1-2)
- ✅ Instalar TheLions Server
- ✅ Configurar Active Directory
- ✅ Instalar e-Cidade
- ✅ Configurar autenticação LDAP no e-Cidade

### Fase 2: Integração Básica (Mês 3-4)
- ✅ Implementar SSO completo
- ✅ Sincronização automática de usuários
- ✅ Configurar File Server para documentos

### Fase 3: Automação (Mês 5-6)
- ✅ Notificações do e-Cidade no chat
- ✅ Abertura de chamados GLPI
- ✅ Dashboard unificado

### Fase 4: Otimização (Mês 7+)
- ✅ Relatórios integrados
- ✅ Workflows automatizados
- ✅ Mobile app

---

## 💰 Proposta Comercial Integrada

### Pacote Completo: TheLions + e-Cidade

**Para Prefeituras de até 100 funcionários:**

| Item | Descrição | Valor Mensal |
|------|-----------|--------------|
| **TheLions Server** | Infraestrutura de TI completa | R$ 2.500 |
| **e-Cidade** | ERP para gestão pública | R$ 3.000* |
| **Integração** | SSO, notificações, dashboard | R$ 500 |
| **Suporte** | Técnico especializado | Incluso |
| **TOTAL** | Solução completa | **R$ 6.000/mês** |

*Valor estimado - verificar com fornecedor do e-Cidade

**Setup inicial:** R$ 15.000 (único)

### Economia vs Soluções Proprietárias

| Solução | Custo Mensal | Economia |
|---------|--------------|----------|
| **Pacote TheLions + e-Cidade** | R$ 6.000 | - |
| **Windows Server + Exchange + ERP Proprietário** | R$ 18.000+ | **66%** |

---

## 📞 Parceiros Estratégicos

### Fornecedores de e-Cidade

1. **DBSeller** - https://dbseller.com.br
2. **Contass** - https://contass.com.br
3. **Fiorilli** - https://fiorilli.com.br

**Estratégia:** Parceria de revenda cruzada
- The Lions vende TheLions Server
- Parceiro vende e-Cidade
- Ambos ganham comissão

---

## 🎯 Diferenciais Competitivos

### Por que TheLions + e-Cidade?

1. ✅ **Solução 100% Integrada**
   - Login único (SSO)
   - Dados centralizados
   - Interface unificada

2. ✅ **100% Software Livre**
   - Sem vendor lock-in
   - Código aberto
   - Comunidade ativa

3. ✅ **Suporte Local**
   - Equipe brasileira
   - Atendimento humanizado
   - Conhecimento da legislação

4. ✅ **Economia Comprovada**
   - 60-80% mais barato que proprietário
   - ROI em 6-12 meses
   - Sem custos ocultos

5. ✅ **Conformidade Legal**
   - LGPD compliant
   - TCE/TCU compliant
   - Soberania digital

---

## 📚 Referências Técnicas

### Documentação

- [e-Cidade - Portal Oficial](https://softwarepublico.gov.br/social/e-cidade)
- [e-Cidade - GitHub](https://github.com/e-cidade/e-cidade)
- [Samba 4 AD - Wiki](https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller)
- [Openfire REST API](https://www.igniterealtime.org/projects/openfire/plugins/restapi/readme.html)
- [GLPI API](https://github.com/glpi-project/glpi/blob/master/apirest.md)

### Casos de Sucesso

- **Prefeitura de Belo Horizonte/MG** - e-Cidade + infraestrutura própria
- **Prefeitura de Canoas/RS** - Pioneira no e-Cidade
- **Prefeitura de Contagem/MG** - Referência em software livre

---

## 🤝 Suporte e Consultoria

### The Lions Informática

- 📧 **Email:** integracao@thelionsinformatica.com.br
- 📱 **WhatsApp:** (XX) XXXX-XXXX
- 🌐 **Website:** www.thelionsinformatica.com.br
- 🐙 **GitHub:** @Thelionsinformatica

### Serviços Oferecidos

- ✅ Consultoria de integração
- ✅ Implantação completa
- ✅ Treinamento de equipes
- ✅ Suporte técnico especializado
- ✅ Desenvolvimento de customizações

---

**Desenvolvido por The Lions Informática** 🦁  
**Transformando a Gestão Pública Brasileira** 🇧🇷
