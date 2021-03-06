# Need on path: boomer & robot

all: rhea-boom.txt

rhea2%.tsv:
	curl -L -O ftp://ftp.expasy.org/databases/rhea/tsv/rhea2$*.tsv
.PRECIOUS: rhea2%.tsv

# Prefer subclass for Reactome
rhea-reactome-probs.tsv: rhea2reactome.tsv
	tail -n +2 $< | cut -f 1,4 | sed '/^$$/d' | sed 's/^/RHEA:/' | sed 's/	/	REACTOME:/' | sed 's/$$/	0.10	0.70	0.15	0.05/' >$@ #$*

# Prefer equivalent class for most mappings
rhea-%-probs.tsv: rhea2%.tsv
	tail -n +2 $< | cut -f 1,4 | sed '/^$$/d' | sed 's/^/RHEA:/' | sed 's/	/	$(shell echo $* | tr [:lower:] [:upper:]):/' | sed 's/$$/	0.10	0.10	0.75	0.05/' >$@
.PRECIOUS: rhea-%-probs.tsv

rhea-relationships.tsv:
	curl -L -O ftp://ftp.expasy.org/databases/rhea/tsv/rhea-relationships.tsv

rhea-relationships.ofn: rhea-relationships.tsv
	cp rhea-relationships-head.txt $@.tmp &&\
	tail -n +2 $< | sed 's/^/SubClassOf(RHEA:/' | sed 's/	is_a	/ RHEA:/' | sed 's/$$/)/' >>$@.tmp &&\
	echo ')' >> $@.tmp && mv $@.tmp $@

go-plus.owl:
	curl -L -O http://purl.obolibrary.org/obo/go/snapshot/extensions/go-plus.owl

go-ec-rhea-xrefs.tsv: go-plus.owl xrefs.rq
	robot query -i $< -f TSV -q xrefs.rq $@

go-ec-rhea-xrefs-probs.tsv: go-ec-rhea-xrefs.tsv
	tail -n +2 $< | sed 's/^<http:\/\/purl.obolibrary.org\/obo\/GO_/GO:/' | sed 's/>//' | sed 's/"//g' | sed 's/$$/	0.10	0.10	0.75	0.05/' >$@

probs.tsv: rhea-ec-probs.tsv rhea-metacyc-probs.tsv rhea-reactome-probs.tsv go-ec-rhea-xrefs-probs.tsv
	cat $^ >$@

go-rhea.ofn: go-plus.owl rhea-relationships.ofn
	robot merge -i go-plus.owl -i rhea-relationships.ofn -o $@

rhea-boom.txt: go-rhea.ofn probs.tsv prefixes.yaml
	boomer --ptable probs.tsv --ontology go-rhea.ofn --window-count 20 --runs 100 --prefixes prefixes.yaml --output rhea-boom
