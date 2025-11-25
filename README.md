# Projeto Final de Administração de Redes de Computadores — ConectaCiência

**Aluno:** Tiago Cardoso Ferreira
**Projeto (Entrega):** Etapa 01 e Etapa 02
**Servidor Linux escolhido:** Ubuntu Server 22.04
**Rede escolhida:** 192.168.100.0/24 (Host-only)
**Nome de domínio interno:** `tiago.local`
**Topologia:** 1 servidor + 1 cliente (VMs)
**Formato de entrega solicitado:** PDF

---

## Sumário

1. Introdução
2. Objetivos
3. Topologia e Diagrama de Rede
4. Endereçamento IP e Segmentação
5. Requisitos de cada serviço
6. Passo a passo de implementação (com arquivos de configuração)

   * Configuração inicial do servidor
   * DHCP (isc-dhcp-server)
   * DNS (bind9)
   * Web (apache2)
   * FTP (vsftpd)
   * NFS
7. Testes e verificação de funcionamento
8. Estrutura do repositório Git (README)
9. Conclusão
10. Anexos: arquivos de configuração (prontos para copiar)

---

## 1. Introdução

Este projeto apresenta o design, implantação e testes de uma pequena rede corporativa para a empresa fictícia **ConectaCiência**. O ambiente usa VirtualBox com máquinas virtuais rodando Ubuntu Server 22.04. No servidor principal serão configurados serviços essenciais: DHCP, DNS, Web, FTP e NFS. A rede interna adotada é 192.168.100.0/24 (Host-only), com o servidor em 192.168.100.10.

## 2. Objetivos

* Projetar a topologia e o endereçamento da rede.
* Instalar e configurar serviços em Linux: DHCP, DNS, Web, FTP e NFS.
* Documentar todo o processo no Git com os arquivos de configuração e testes.
* Entregar um documento final em PDF descrevendo o projeto e os resultados.

## 3. Topologia e Diagrama de Rede

```
[Internet/NAT - VirtualBox NAT] (opcional)
        |
    (Host)
        |
------------------------------ Host-Only Network ------------------------------
|                                                                              |
|   +----------------+             +-----------------+                        |
|   |  Servidor VM   |             |   Cliente VM    |                        |
|   | Ubuntu 22.04   |             | Ubuntu (Desktop)|                        |
|   | IP: 192.168.100.10 (estático)|  IP: (via DHCP)  |                        |
|   +----------------+             +-----------------+                        |
|                                                                              |
--------------------------------------------------------------------------------

Serviços no Servidor: DHCP, DNS (tiago.local), Apache, vsftpd, NFS
```

> **Nota:** use 2 adaptadores de rede nas VMs: NAT (para acesso à internet/apt) + Host-only (192.168.100.0/24) para comunicação interna.

## 4. Endereçamento IP e Segmentação

| Dispositivo    | Função            | IP (sugerido)                 |
| -------------- | ----------------- | ----------------------------- |
| Servidor       | Todos os serviços | 192.168.100.10/24             |
| Cliente (VM)   | Testes            | DHCP -> 192.168.100.50–100    |
| Gateway/Router | (opcional)        | 192.168.100.1 (se necessário) |

Máscara: 255.255.255.0 (/24)
DHCP Range: 192.168.100.50 - 192.168.100.100
DNS interno: `tiago.local` resolvendo `servidor.tiago.local` -> 192.168.100.10

## 5. Requisitos de cada serviço

* **DHCP:** Atribuição automática de endereços IP aos clientes da rede host-only.
* **DNS:** Resolução de nomes locais (`tiago.local`) para facilitar acesso aos serviços.
* **Web (Apache):** Hospedar página interna com informações da ConectaCiência.
* **FTP (vsftpd):** Transferência de arquivos entre clientes e servidor.
* **NFS:** Compartilhamento de diretórios entre servidor e cliente(s).

## 6. Passo a passo de implementação

### 6.0 Preparação do servidor (Ubuntu Server 22.04)

1. Atualizar pacotes e instalar utilitários:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y vim git curl wget net-tools tcpdump
```

2. Certificar que as VMs tenham dois adaptadores: NAT (internet) e Host-only (192.168.100.0/24).
3. Configurar IP estático no servidor (netplan): `/etc/netplan/01-netcfg.yaml` exemplo:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: true    # NAT (internet)
    enp0s8:
      dhcp4: false
      addresses: [192.168.100.10/24]
      gateway4: 192.168.100.1
      nameservers:
        addresses: [8.8.8.8,8.8.4.4]
```

Aplicar: `sudo netplan apply`

---

### 6.1 DHCP — isc-dhcp-server

**Instalação:**

```bash
sudo apt install -y isc-dhcp-server
```

**Arquivo de configuração principal:** `/etc/dhcp/dhcpd.conf` (substitua o conteúdo atual):

```conf
# dhcpd.conf - ConectaCiência
default-lease-time 600;
max-lease-time 7200;
authoritative;

option domain-name "tiago.local";
option domain-name-servers 192.168.100.10;

subnet 192.168.100.0 netmask 255.255.255.0 {
  range 192.168.100.50 192.168.100.100;
  option routers 192.168.100.10; # se o servidor atuar como gateway
  option broadcast-address 192.168.100.255;
}

# Reservar IP para o servidor (opcional)
host servidor {
  hardware ethernet 00:11:22:33:44:55; # coloque a MAC real se quiser
  fixed-address 192.168.100.10;
}
```

**Definir interface do isc-dhcp-server:** editar `/etc/default/isc-dhcp-server` e ajustar `INTERFACESv4="enp0s8"` (interface host-only).

**Reiniciar serviço:** `sudo systemctl restart isc-dhcp-server` e verificar status `sudo systemctl status isc-dhcp-server`.

**No cliente:**

```bash
sudo dhclient -v enp0s8
ip a  # verificar se obteve IP do range
```

---

### 6.2 DNS — Bind9

**Instalação:**

```bash
sudo apt install -y bind9
```

**Configuração (exemplos):**

* Arquivo de zonas será criado em `/etc/bind`.

**Editar `/etc/bind/named.conf.local` e adicionar:**

```conf
zone "tiago.local" {
  type master;
  file "/etc/bind/zones/db.tiago.local";
};

zone "100.168.192.in-addr.arpa" {
  type master;
  file "/etc/bind/zones/db.192.168.100";
};
```

**Criar diretório de zones:** `sudo mkdir -p /etc/bind/zones`

**Arquivo `/etc/bind/zones/db.tiago.local`:**

```dns
$TTL 604800
@   IN  SOA ns.tiago.local. admin.tiago.local. (
        20251124 ; Serial (YYYYMMDD)
        604800   ; refresh
        86400    ; retry
        2419200  ; expire
        604800 ) ; negative cache

; Nameserver
@       IN  NS      ns.tiago.local.
ns      IN  A       192.168.100.10

; Hosts
@       IN  A       192.168.100.10
servidor IN A       192.168.100.10

; MX (opcional)
; @ IN MX 10 mail.tiago.local.
```

**Reverse `/etc/bind/zones/db.192.168.100`:**

```dns
$TTL 604800
@   IN  SOA ns.tiago.local. admin.tiago.local. (
        20251124 ; Serial
        604800
        86400
        2419200
        604800 )

@       IN  NS ns.tiago.local.
10      IN  PTR servidor.tiago.local.
```

**Ajustar `/etc/resolv.conf` ou netplan nameserver para apontar para 192.168.100.10**
**Reiniciar bind:** `sudo systemctl restart bind9`.

**Testes:**

```bash
nslookup servidor.tiago.local 192.168.100.10
dig @192.168.100.10 servidor.tiago.local
```

---

### 6.3 Servidor Web — Apache2

**Instalação:**

```bash
sudo apt install -y apache2
```

**Arquivo do site (exemplo) `/var/www/tiago.local/index.html`**

```html
<html>
  <head><title>ConectaCiência — Intranet</title></head>
  <body>
    <h1>ConectaCiência — Rede Interna</h1>
    <p>Servidor: servidor.tiago.local (192.168.100.10)</p>
  </body>
</html>
```

**Config VirtualHost `/etc/apache2/sites-available/tiago.local.conf`:**

```conf
<VirtualHost *:80>
    ServerName servidor.tiago.local
    DocumentRoot /var/www/tiago.local
    ErrorLog ${APACHE_LOG_DIR}/tiago_error.log
    CustomLog ${APACHE_LOG_DIR}/tiago_access.log combined
</VirtualHost>
```

**Ativar site e reiniciar:**

```bash
sudo a2ensite tiago.local
sudo systemctl reload apache2
```

**Testar:** abrir `http://servidor.tiago.local` no cliente (ou `http://192.168.100.10`).

---

### 6.4 FTP — vsftpd

**Instalar:**

```bash
sudo apt install -y vsftpd
```

**Arquivo de configuração `/etc/vsftpd.conf` (config mínima segura para testes):**

```conf
listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
pasv_min_port=40000
pasv_max_port=40100
```

**Criar usuário para FTP (exemplo):**

```bash
sudo adduser ftpuser
# definir senha
sudo mkdir -p /home/ftpuser/ftp/upload
sudo chown -R ftpuser:ftpuser /home/ftpuser/ftp
```

**Reiniciar vsftpd:** `sudo systemctl restart vsftpd`.

**Testar:** no cliente:

```bash
ftp servidor.tiago.local
# ou usar FileZilla apontando para 192.168.100.10
```

---

### 6.5 NFS (Network File System)

**Instalar no servidor:**

```bash
sudo apt install -y nfs-kernel-server
```

**Criar diretório a ser compartilhado:**

```bash
sudo mkdir -p /srv/nfs/shared
sudo chown nobody:nogroup /srv/nfs/shared
sudo chmod 0777 /srv/nfs/shared
```

**Editar `/etc/exports` e adicionar:**

```
/srv/nfs/shared 192.168.100.0/24(rw,sync,no_subtree_check)
```

**Aplicar e reiniciar:**

```bash
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
```

**No cliente:**

```bash
sudo apt install -y nfs-common
sudo mount 192.168.100.10:/srv/nfs/shared /mnt
ls /mnt
```

---

## 7. Testes e verificação de funcionamento

Para cada serviço, registrar o teste em Git com prints ou logs:

* **DHCP:** `ip a` no cliente para mostrar IP na faixa 192.168.100.50–100
* **DNS:** `dig @192.168.100.10 servidor.tiago.local` -> deve responder 192.168.100.10
* **Web:** abrir `http://servidor.tiago.local` ou `http://192.168.100.10`
* **FTP:** conectar com `ftpuser` e fazer upload/download
* **NFS:** criar arquivo em `/mnt` no cliente e verificar no servidor

Exemplos de comandos para coletar evidências:

```bash
# DHCP
ip -4 addr show enp0s8
# DNS
dig @192.168.100.10 servidor.tiago.local
# HTTP
curl -I http://192.168.100.10
# FTP (linhas de log)
sudo tail -n 50 /var/log/vsftpd.log
# NFS
ls -la /mnt
```

Registre também saídas do `systemctl status` para cada serviço.

---

## 8. Estrutura do repositório Git (README)

Estrutura sugerida:

```
conectaciencia-project/
├─ docs/
│  └─ projeto_final_conexao.pdf   # documento final (gerado)
├─ configs/
│  ├─ dhcpd.conf
│  ├─ named.conf.local
│  ├─ db.tiago.local
│  ├─ db.192.168.100
│  ├─ tiago.local.conf (apache)
│  ├─ vsftpd.conf
│  └─ exports
├─ scripts/
│  └─ setup_server.sh
└─ README.md
```

**README.md (sugestão resumida):**

```
# ConectaCiência - Projeto de Administração de Redes

Descrição do projeto, topologia, serviços implementados e instruções rápidas para replicar o ambiente.

## Como usar
1. Clonar repositório
2. Colocar ISOs/VMs e ajustar interfaces de rede
3. Executar scripts em `scripts/setup_server.sh`
```

---

## 9. Conclusão

Resumo do que foi implementado, dificuldades encontradas e recomendações para produção (segurança, backups, TLS para web, usuários e permissões no FTP, firewall UFW/iptables).

---

## 10. Anexos — Arquivos de configuração prontos (copiar para os caminhos indicados)

### `/etc/dhcp/dhcpd.conf`

```
default-lease-time 600;
max-lease-time 7200;
authoritative;

option domain-name "tiago.local";
option domain-name-servers 192.168.100.10;

subnet 192.168.100.0 netmask 255.255.255.0 {
  range 192.168.100.50 192.168.100.100;
  option routers 192.168.100.10;
  option broadcast-address 192.168.100.255;
}

host servidor {
  hardware ethernet 00:11:22:33:44:55;
  fixed-address 192.168.100.10;
}
```

### `/etc/bind/named.conf.local`

```
zone "tiago.local" {
  type master;
  file "/etc/bind/zones/db.tiago.local";
};

zone "100.168.192.in-addr.arpa" {
  type master;
  file "/etc/bind/zones/db.192.168.100";
};
```

### `/etc/bind/zones/db.tiago.local`

```
$TTL 604800
@   IN  SOA ns.tiago.local. admin.tiago.local. (
        20251124 ; Serial
        604800
        86400
        2419200
        604800 )

@       IN  NS      ns.tiago.local.
ns      IN  A       192.168.100.10

@       IN  A       192.168.100.10
servidor IN A       192.168.100.10
```

### `/etc/bind/zones/db.192.168.100`

```
$TTL 604800
@   IN  SOA ns.tiago.local. admin.tiago.local. (
        20251124 ; Serial
        604800
        86400
        2419200
        604800 )

@       IN  NS ns.tiago.local.
10      IN  PTR servidor.tiago.local.
```

### `/etc/apache2/sites-available/tiago.local.conf`

```
<VirtualHost *:80>
    ServerName servidor.tiago.local
    DocumentRoot /var/www/tiago.local
    ErrorLog ${APACHE_LOG_DIR}/tiago_error.log
    CustomLog ${APACHE_LOG_DIR}/tiago_access.log combined
</VirtualHost>
```

### `/etc/vsftpd.conf` (mínimo)

```
listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
pasv_min_port=40000
pasv_max_port=40100
```

### `/etc/exports`

```
/srv/nfs/shared 192.168.100.0/24(rw,sync,no_subtree_check)
```

---

## Scripts sugeridos (scripts/setup_server.sh)

```bash
#!/bin/bash
set -e

sudo apt update && sudo apt install -y isc-dhcp-server bind9 apache2 vsftpd nfs-kernel-server
# copiar arquivos de configs do diretório configs/
# aplicar netplan, reiniciar serviços
sudo systemctl restart isc-dhcp-server bind9 apache2 vsftpd nfs-kernel-server
```

---

## Como eu entrego os artefatos para você

1. Este documento será transformado em PDF para entrega final.
2. Configure um repositório Git e envie os arquivos de configuração e scripts.
3. Tire prints dos testes e coloque em `/docs` no repositório.

---

## Próximos passos que eu posso executar para você (me diga o que prefere):

* Gerar o PDF pronto (eu já organizei o conteúdo).
* Gerar os arquivos de configuração separados e um `setup_server.sh` (prontos para download).
* Gerar um README.md completo e um modelo de repositório ZIP com tudo.

---

*Fim do documento.*
