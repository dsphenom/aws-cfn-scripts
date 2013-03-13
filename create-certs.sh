openssl genpkey -algorithm RSA -out pk-serial.pem
openssl req -new -key pk-serial.pem -out cert-serial.csr
openssl x509 -req -days 365 -in cert-serial.csr -signkey pk-serial.pem -out cert-serial.crt
