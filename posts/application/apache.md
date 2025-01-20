# Linux Web Server 'Apache' Build
---

## TCP 3-way Handshaking
1. Web Client -> TCP Sync -> Web Server : Request
2. Web Client <- SYN + ACK <- Web Server : Response
3. Web Client -> ACK -> Web Server

TCP Flags : SYN, ACK, FZN, PSH ...

YUM, DNF(dandfied yum) : 패키지 관리도구

<br><br>

## APM (Apache, PHP, MySQL or MariaDB)
수행 환경: Oracle VM VirtualBox

### 1. Apache
`dnf install -y httpd php mariadb-server` : -y(yes), httpd(Apache), php, mariadb-server 설치 <br>
`rpm -qa` : 머신에 있는 모든 Red Hat Package 출력 <br>
`systemctl status httpd` : httpd 서비스 정보 출력 <br>
`systemctl start/stop/restart httpd` : httpd 서비스 시작,정지,재시작 <br>
`systemctl enable/disable httpd` : 재부팅 시에도 httpd 서비스를 시작하도록 설정/미설정 <br>
`firewall-cmd --list-all` : 현재 방화벽 상태 정보 출력 <br>
`firewall-cmd --permanent ~~` : 재부팅시에도 ~내용을 유지 <br>
`firewall-cmd --permanent --add-service=http` : httpd 서비스 방화벽 변경 <br>
`firewall-cmd --reload` : 변경된 방화벽을 적용, 서비스 변경 후 반드시 적용 <br>

Desktop browser: http://VirtualBox IP Address -> 웹페이지 작동 확인<br>
<img src="../posts/application/img/apache1.png" alt="Apache 웹서버 테스트" width="800px" style="display: block; margin: 0 auto;">
<br>

### 2. PHP
`/etc/httpd directory` : web server root directory<br>
`httpd.conf 파일 (/etc/http.conf)` : httpd server의 구성<br>

`/var/www/html directory` : document root directory<br>
`vi index.html` or `vi index.php` : 웹페이지 작성<br>
```html
<html>
<body>
    <h1>Hello World</h1>
</body>
</html>
```

`index.html` : start page, html, php file이 여러개 있더라도 서버의 시작 페이지는 index.html 또는 index.php


