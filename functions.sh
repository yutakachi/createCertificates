function createDir () {
    mkdir -p ./$ROOTCA/private
    mkdir -p ./$ROOTCA/newcerts
    mkdir -p ./$ROOTCA/$DOMAIN/certs
    mkdir -p ./$ROOTCA/$DOMAIN/private
}
