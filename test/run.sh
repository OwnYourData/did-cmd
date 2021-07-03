#!/usr/bin/env bash

OYDIDCMD='../oydid.rb'
# OYDIDCMD='oydid'

# install current version
sh -c "curl -fsSL https://raw.githubusercontent.com/OwnYourData/did-cmd/main/install.sh | sh"

# clean up
$OYDIDCMD delete did:oyd:22h3zy8Yi2dtQ6UzQKDa85e5FTA3316gTpPysw7KAS7V --doc-pwd pwd1 --rev-pwd pwd2 --silent
$OYDIDCMD delete 57c9p6AGUzsqGcBb1AuZS5mEDUqDSVfKV2QnuG9HjwKB --doc-pwd pwd1 --rev-pwd pwd2 --silent
$OYDIDCMD delete "did:oyd:fUozLeLj2xa4rjY9CCUJWe78JFFWCa2Xvkf1aAusHdXE;https://did2.data-container.net" --doc-pwd pwd1 --rev-pwd pwd2 --silent
$OYDIDCMD delete did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58 --silent
$OYDIDCMD delete 9Gsid3RsCC24gHF1AkGW5FoHXQ8mbmbk5AW4KTs36ADy --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58 --silent
$OYDIDCMD delete "did:oyd:8VxvgoVo2dUBxGvQ9NzsCLS8YTWSthvtxd88XLd9NNxE;https://did2.data-container.net" --doc-pwd pwd1 --rev-pwd pwd2 --silent


# test creating local DID Document
echo '{"hello": "world"}' | $OYDIDCMD create -l local --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58 --ts 1610839947
if ! cmp -s 5QW66zAqWn.doc c1/did.doc ; then
	echo "creating failed"
	exit 1
fi
rm 5*

# test creating invalid DID Document
retval=`echo '{' | $OYDIDCMD create -l local --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58`
if [ "$retval" == "Error: empty or invalid payload" ]; then
	echo "invalid input handled"
else
	echo "processing invalid input failed"
	exit 1
fi

# test creating public DID Document
echo '{"hello": "world2"}' | $OYDIDCMD create --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58 --ts 1610839947
$OYDIDCMD read did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu > tmp.doc
if ! cmp -s tmp.doc c1/8LZMwgahJp.doc ; then
	echo "reading from public failed"
	exit 1
fi
$OYDIDCMD read --w3c-did did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu > tmp.doc
if ! cmp -s tmp.doc c1/w3c-did.doc ; then
	echo "converting to W3C DID format failed"
	exit 1
fi
rm tmp.doc

# test updating DID Document
echo '{"hello": "world3"}' | $OYDIDCMD update did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58 --ts 1610839948
$OYDIDCMD read did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu > tmp.doc
if ! cmp -s tmp.doc c1/9Gsid3RsCC.doc ; then
	echo "updating public failed"
	exit 1
fi
rm tmp.doc

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

# test writing to non-default location
echo '{"hello": "world6"}' | $OYDIDCMD create -l https://did2.data-container.net --doc-pwd pwd1 --rev-pwd pwd2 --ts 1610839947
$OYDIDCMD read "did:oyd:fUozLeLj2xa4rjY9CCUJWe78JFFWCa2Xvkf1aAusHdXE;https://did2.data-container.net" > tmp.doc
if ! cmp -s tmp.doc c1/did2.doc ; then
	echo "writing to non-default location failed"
	exit 1
fi
rm tmp.doc
$OYDIDCMD delete "did:oyd:fUozLeLj2xa4rjY9CCUJWe78JFFWCa2Xvkf1aAusHdXE;https://did2.data-container.net" --doc-pwd pwd1 --rev-pwd pwd2

# test clone
$OYDIDCMD clone did:oyd:9Gsid3RsCC24gHF1AkGW5FoHXQ8mbmbk5AW4KTs36ADy --doc-pwd pwd1 --rev-pwd pwd2 --ts 1610839948 -l https://did2.data-container.net
$OYDIDCMD read "did:oyd:8VxvgoVo2dUBxGvQ9NzsCLS8YTWSthvtxd88XLd9NNxE;https://did2.data-container.net" > tmp.doc
if ! cmp -s tmp.doc c1/did_clone.doc ; then
	echo "cloning failed"
	exit 1
fi
rm tmp.doc

# $OYDIDCMD delete did:oyd:8LZMwgahJpLCUuwVEzY6SqzzpooMETZ3gaQdprZ8bhRu --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58
# $OYDIDCMD delete 9Gsid3RsCC24gHF1AkGW5FoHXQ8mbmbk5AW4KTs36ADy --doc-key c1/private_key.b58 --rev-key c1/revocation_key.b58
# $OYDIDCMD delete "did:oyd:8VxvgoVo2dUBxGvQ9NzsCLS8YTWSthvtxd88XLd9NNxE;https://did2.data-container.net" --doc-pwd pwd1 --rev-pwd pwd2 

echo "tests finished successfully"
