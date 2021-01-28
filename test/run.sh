#!/usr/bin/env bash

OYDIDCMD='../oydid.rb'
# OYDIDCMD='oydid'

# install current version
sh -c "curl -fsSL https://raw.githubusercontent.com/OwnYourData/did-cmd/main/install.sh | sh"

# test creating local DID Document
echo '{"hello": "world"}' | $OYDIDCMD create -l local --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58 --ts 1610839947
if ! cmp -s 5QW66zAqWn.doc c1/did.doc ; then
	echo "creating failed"
	exit 1
fi
rm 5*

# test creating public DID Document
echo '{"hello": "world2"}' | $OYDIDCMD create --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58 --ts 1610839947
$OYDIDCMD read did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu > tmp.doc
if ! cmp -s tmp.doc c1/8LZMwgahJp.doc ; then
	echo "reading from public failed"
	exit 1
fi
rm 8* tmp.doc

# test updating DID Document
echo '{"hello": "world3"}' | $OYDIDCMD update did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58 --ts 1610839948
$OYDIDCMD read did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu > tmp.doc
if ! cmp -s tmp.doc c1/9Gsid3RsCC.doc ; then
	echo "updating public failed"
	exit 1
fi
rm 9G* tmp.doc
$OYDIDCMD delete did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58
$OYDIDCMD delete 9Gsid3RsCC24gHF1AkGW5FoHXQ8mbmbk5AW4KTs36ADy --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58


# test creating public DID Document with password
echo '{"hello": "world4"}' | $OYDIDCMD create --doc-pwd pwd1 --rev-pwd pwd2 --ts 1610839947
$OYDIDCMD read did:oyd:22h3zy8Yi2dtQ6UzQKDa85e5FTA3316gTpPysw7KAS7V > tmp.doc
if ! cmp -s tmp.doc c1/pwd.doc ; then
	echo "creating with password failed"
	exit 1
fi
rm tmp.doc

# test updating DID Document with password
echo '{"hello": "world5"}' | $OYDIDCMD update did:oyd:22h3zy8Yi2dtQ6UzQKDa85e5FTA3316gTpPysw7KAS7V --doc-pwd pwd1 --rev-pwd pwd2 --ts 1610839948
$OYDIDCMD read did:oyd:22h3zy8Yi2dtQ6UzQKDa85e5FTA3316gTpPysw7KAS7V > tmp.doc
if ! cmp -s tmp.doc c1/pwd2.doc ; then
	echo "updating with password failed"
	exit 1
fi
rm tmp.doc
$OYDIDCMD delete did:oyd:22h3zy8Yi2dtQ6UzQKDa85e5FTA3316gTpPysw7KAS7V --doc-pwd pwd1 --rev-pwd pwd2
$OYDIDCMD delete 57c9p6AGUzsqGcBb1AuZS5mEDUqDSVfKV2QnuG9HjwKB --doc-pwd pwd1 --rev-pwd pwd2

echo "tests finished successfully"
