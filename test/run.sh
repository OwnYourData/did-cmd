#!/usr/bin/env bash

# OYDIDCMD='../oydid.rb'
OYDIDCMD='oydid'

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
../oydid.rb read did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu > tmp.doc
if ! cmp -s tmp.doc c1/8LZMwgahJp.doc ; then
	echo "reading from public failed"
	exit 1
fi
rm 8* tmp.doc

# test updating DID Document
echo '{"hello": "world3"}' | $OYDIDCMD update did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58 --ts 1610839948
../oydid.rb read did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu > tmp.doc
if ! cmp -s tmp.doc c1/cU9bvp84sT.doc ; then
	echo "updating public failed"
	exit 1
fi
rm cU* tmp.doc

echo "tests finished successfully"
