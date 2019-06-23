
export GENVER=320
export BIN=bin

export PROJBASE=$(PWD)
export DBTYPE=pgs
export GBC=gbc-clean
export GBCPROJDIR=/opt/fourjs/gbc-current
export APP=setlist
export ARCH=$(APP)
export GASCFG=$(FGLASDIR)/etc/as.xcf
export MUSICDIR=~/Music

export RENDERER=ur

export FGLGBCDIR=$(GBCPROJDIR)/dist/customization/$(GBC)
export FGLIMAGEPATH=$(PROJBASE)/pics:$(FGLDIR)/lib/image2font.txt
export FGLRESOURCEPATH=$(PROJBASE)/etc
export FGLPROFILE=$(PROJBASE)/etc/fglprofile

export LANG=en_GB.utf8

TARGETS=\
	gar

all: $(TARGETS)

$(BIN)/$(APP).42r: 
	gsmake $(APP)$(GENVER).4pw

gar: $(BIN)/$(APP).42r

clean:
	find . -name \*.42? -delete
	find . -name \*.zip -delete
	find . -name \*.gar -delete

run: $(BIN)/$(APP).42r
	cd $(BIN); fglrun $(APP).42r


undeploy: 
	cd distbin && gasadmin gar -f $(GASCFG) --disable-archive $(ARCH) | true
	cd distbin && gasadmin gar -f $(GASCFG) --undeploy-archive $(ARCH).gar
	rm -f distbin/.deployed

deploy: 
	cd distbin && gasadmin gar -f $(GASCFG) --deploy-archive $(ARCH).gar
	cd distbin && gasadmin gar -f $(GASCFG) --enable-archive $(ARCH)
	echo "deployed" > distbin/.deployed

redeploy: undeploy deploy



run: $(BIN)/$(APP).42r
	export FGLGBCDIR=$(GBCPROJDIR)/dist/customization/gbc-clean && cd $(BIN) && fglrun $(APP).42r

runclean: $(BIN)/$(APP).42r
	export FGLGBCDIR=$(GBCPROJDIR)/dist/customization/gbc-clean && cd $(BIN) && fglrun $(APP).42r

runnat: $(BIN)/$(APP).42r
	FGLPROFILE=$(PROJBASE)/etc/$(DBTYPE)/profile:$(PROJBASE)/etc/profile.nat && cd $(BIN) && fglrun $(APP).42r

