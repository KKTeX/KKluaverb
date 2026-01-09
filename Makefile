# ----- setting ------
TEST_TARGET = kkluaverb-test
RC     = .latexmkrc


# ----- main ------
.PHONY: all clean distclean pvc zip

# make  = build and clean
all: build clean

# compile
build:
	latexmk -r $(RC) $(TEST_TARGET).tex

# cleaning except for PDF
clean:
	latexmk -c

# cleaning including PDF
distclean:
	latexmk -C

# compile on save
# pvc:
# 	latexmk -pvc -r $(RC) $(TARGET).tex

# ----- CTAN setting -----
PACKAGE = kkluaverb
styFILENAME = KKluaverb
ZIP_DIR = $(PACKAGE)

# ----- zip generation -----
zip: distclean build clean
	mkdir -p $(ZIP_DIR)
	cp $(styFILENAME).lua $(ZIP_DIR)
	cp $(styFILENAME).sty $(ZIP_DIR)
	cp README.md $(ZIP_DIR)
	cp LICENSE.md $(ZIP_DIR)
# 	cp $(PACKAGE).tex $(ZIP_DIR)
# 	cp $(PACKAGE).pdf $(ZIP_DIR)
	zip -r $(PACKAGE).zip $(ZIP_DIR)
	rm -rf $(ZIP_DIR)