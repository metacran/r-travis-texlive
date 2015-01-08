#! /bin/sh

set -ex

export PATH=/usr/local/bin:$PATH

if [ "$DRONE" == "true" ]; then
    export CI="drone"
    export REPO_SLUG=$(echo "$DRONE_REPO_SLUG" | sed -s '/github\.com\///')
    export ADD_REPO="sudo add-apt-repository -y -s"
elif [ "$SEMAPHORE" == "true" ]; then
    export CI="semaphore"
    export REPO_SLUG="$SEMAPHORE_REPO_SLUG"
    export ADD_REPO="sudo add-apt-repository -y -s"
elif [ "$TRAVIS" == "true" ]; then
    export CI="travis"
    export REPO_SLUG="$TRAVIS_REPO_SLUG"
    export ADD_REPO="sudo add-apt-repository"
else
    echo "Unknown CI"
    exit 1
fi

export INSTALLER="http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz"

export tag=${CI}
export branch=${CI}_bin
export PREFIX=$HOME/R-bin/texlive
export EPREFIX=$(echo "$PREFIX" | sed -e 's/[\/&]/\\&/g')

export OS=x86_64-linux
if uname -a | grep -q Darwin; then
    export OS=x86-64-darwin
fi
export EOS=$(echo "$OS" | sed -e 's/[\/&]/\\&/g')

CreateProfile() {
    sed "s/@PREFIX@/${EPREFIX}/g" texlive.profile.in | \
	sed "s/@OS@/${EOS}/g" > texlive.profile
}

Download() {
    #    curl -L ${INSTALLER} | tar xzv
    true
}

Install() {
    (
	mkdir -p $PREFIX
	cd install-tl-*
	# ./install-tl --profile=../texlive.profile
    )
}

SetPath() {
    BINDIR=$(ls $PREFIX/bin | head -1)
    export PATH=$PREFIX/bin/$BINDIR:$PATH
}

InstallPackage() {
    tlmgr install "$@"
}

InstallExtra() {
    InstallPackage inconsolata texinfo ec times helvetic courier
}

Deploy() {
    (
	cd /tmp
	git config --global user.name "Gabor Csardi"
	git config --global user.email "csardi.gabor@gmail.com"
	git config --global push.default matching

	mkdir _deploy
	cd _deploy
	git init .
	git symbolic-ref HEAD refs/heads/${branch}
	cp -r ${PREFIX} .
	git add -A .

	git remote add origin https://github.com/"${REPO_SLUG}"
	git remote set-branches --add origin ${branch}
	git config credential.helper "store --file=.git/credentials"
	python -c 'import os; print "https://" + os.environ["GH_TOKEN"] + ":@github.com"' > .git/credentials

	git commit -q --allow-empty -m "Building R ${version} on ${CI}"
	git tag -d ${tag} || true
	git tag ${tag}
	git push -f --tags -q origin ${branch}
    )
}

CreateProfile
Download
Install
SetPath
InstallExtra
Deploy
