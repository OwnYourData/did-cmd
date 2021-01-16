#!/usr/bin/env bash

# install current version
sh -c "curl -fsSL https://raw.githubusercontent.com/OwnYourData/did-cmd/main/install.sh | sh"

# test creating local DID Document
echo '{"hello": "world"}' | oydid create -l local --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58 --ts 1610839947
if ! cmp -s 5QW66zAqWn.doc c1/did.doc ; then
	echo "creating failed"
	exit 1
fi
rm 5*

# test creating public DID Document
echo '{"hello": "world2"}' | oydid create --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58 --ts 1610839947
../oydid.rb read did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu > tmp.doc
if ! cmp -s tmp.doc c1/8LZMwgahJp.doc ; then
	echo "reading from public failed"
	exit 1
fi
rm 8* tmp.doc

echo "tests finished successfully"
