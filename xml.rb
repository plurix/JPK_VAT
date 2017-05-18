################################################################################
# Copyright (C) 2017 PLURIX Jerzy Klaczak <jpk_vat@plurix.com.pl>
# 
# All rights reserved. This program and the accompanying materials
# is free software; you can redistribute it and/or
# modify it under the terms of the GNU Affero General Public License version 3.0,
# which accompanies this distribution, and is available at
# https://choosealicense.com/licenses/agpl-3.0/
# as published by the GitHub.
# 
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330,
# Boston, MA 02111-1307 USA.
#
# Contributors:
#		Jerzy Klaczak PLURIX - concept and implementation
# Parts of this code are based on code from .......
#       http://www.xml.com/pub/a/2005/11/09/rexml-processing-xml-in-ruby.html
#       http://www.germane-software.com/software/XML/rexml/doc/
################################################################################ 

begin
require 'rexml/document' #REXML is non-validating parser, doesn't expand EXTERNAL entities (internal - does: <!ENTITY name "value">)
include REXML	#include namespace REXML::
# require 'date'	# DateTime  http://ruby-doc.org/stdlib-1.9.3/libdoc/date/rdoc/DateTime.html
require 'bigdecimal'	#http://ruby-doc.org/stdlib-2.2.0/libdoc/bigdecimal/rdoc/BigDecimal.html

puts "(C)PLURIX(R)2017 - analiza pliku JPK.XML"
# xml = File.open("JPK1.xml") # albo File.new
xml = nil
until xml
	print "Wprowadz nazwe pliku XML: "
	n = gets.strip
	unless File.exist? n 
		puts "Nie ma takiego zbioru: #{n} !"; next
	end
	xml = File.open(n, 'r')
end
# xml = File.open("JPK1.xml") # albo File.new
print "czytam..."
doc = Document.new(xml)	# may be: IO (File|Socket) | Document | String | EMPTY (creates empty doc); outputs <UNDEFINED>...</>
xml.close
print "przetwarzam..."
$log = File.new("JPK.log", "w")
$out = $log
$out.print "(C)PLURIX(R) - analiza JPK(2)\n"
# doc.write(out,2)	# write out XML tree (with pretty-printing: 2 spaces)

$blad = ""

$naglowek = Hash.new()
$curLevel = 0
$nodes = doc.elements
$root = doc.root
$levels = []
$positions = []
$maxPos = 1
$curPos = 1
$curNode = $root # ??? doc ???
$attrs = []
$attrNo = 0
$VieSchema = [/ATU\d{8}/,  /BE0?\d{9}/,  /BG\d{9,10}/,  /CY\d{8}[A-Z]/,  /CZ\d{8,10}/,  /DE\d{9}/,  /DK\d{8}/,  /EE\d{9}/,  /EL\d{9}/,  /ES[A-Z\d]\d{7}[A-Z\d]/,  /FI\d{8}/,  /FR[A-HJ-NP-Z\d]{2}\d{9}/,  /GB(HA|GD)\d{3}/,  /GB\d{9}(\d{3})?/,  /HU\d{8}/,  /IE\d[A-Za-z+*\d]\d{5}[A-Za-z]/,  /IT\d{11}/,  /LT\d{9}(\d{3})?/,  /LU\d{8}/,  /LV\d{11}/,  /MT\d{8}/,  /NL\d{9}B\d{2}/,  /PT\d{9}/,  /RO\d{2,10}/,  /SE\d{12}/,  /SI\d{8}/,  /SK\d{10}/]

def error(text, sygnal="Blad wykonania JPK")
	print "#{text} #{sygnal}" # @L lineno, @C charno => $out && same to window
	$log.print "#{text} #{sygnal}" # @L lineno, @C charno => $out && same to window
	puts "\n"
	print "!!! BLAD !!! aby zamknac - wcisnij ENTER:"
	gets
	raise sygnal
end
def signal(text, nl="\n")
	$out.print text.strip+nl
end
def nonEmpty(text, klucz)
	$naglowek[klucz] ? text+$naglowek[klucz] : ""
end
def italian(ansi)
	return ansi[8..9]+ansi[4..7]+ansi[0..3]
end
def checkDate(ansi)
	error "Zly format daty: #{ansi}" unless ansi =~/^\d\d\d\d-\d\d-\d\d/
	t = Time.local ansi[0..3], ansi[5..6], ansi[8..9] rescue error "Bledny format daty #{ansi}"
	error "JPK lata 2017..2030, a nie #{ansi[0..3]}" unless t.between? Time.local(2017), Time.local(2031)
	return t
end
def plNip(nip)
	error "NIP w PL 10 cyfr, a nie #{nip}" unless nip =~ /^\d{10}$/
	s = 0; 9.times {|i| s+= nip[i].to_i * "657234567"[i].to_i}
	if (s%11)%10 != nip[9].to_i
		$blad = "Blad sumy kontrolnej NIP: #{nip}" 
		return nil
	end
	$blad = ""
	return 1
end
def ueNIP(nip)	# http://vat-number-validation.eu/vies/?lang=pl
	kraj = nip[0..1]
	return plNip nip if kraj =~ /\d\d/	# krajowy bez PL
	return plNip nip[2..-1]	if kraj == "PL"	# PL explicite
	trim = nip.strip; $blad = ""
	$VieSchema.each {|v| return true if trim =~ v}
	$blad = "Numer NIP: #{nip} nie jest poprawny dla kraju #{kraj}"; return nil
end
def dzial(name, attr=false, space:"tns")
	error "nie ma nastepnego dzialu #{name}" if $maxPos < $curPos
	$curNode = $nodes[$curPos]
	error "ma byc dzial #{name} jest #{$curNode.name}" if "#{space}:#{name}" != "#{$curNode.prefix}:#{$curNode.name}"
	$attrs = []
	$curNode.attributes.each {|key, val| $attrs << key} # $attrs = $curNode.attributes.keys
	$attrNo = 0
	error "Musza byc atrybuty w dziale #{name}" if attr and $attrs.empty?
	error "Nie ma byc atrybutow w dziale #{name}: #{$attrs}" if not attr and not $attrs.empty?
	$curPos+= 1	# but curNode remains on on THIS node
end
def ifDzial(name, attr=false, space:"tns")
	return nil if $maxPos < $curPos # nie ma nastepnego elementu
	$curNode = $nodes[$curPos]
	return nil if "#{space}:#{name}" != "#{$curNode.prefix}:#{$curNode.name}" # jest nastepny element, ale inna nazwa
	$attrs = []
	$curNode.attributes.each {|key, val| $attrs << key}
	$attrNo = 0
	error "Musza byc atrybuty w dziale #{name}" if attr and $attrs.empty?
	error "Nie ma byc atrybutow w dziale #{name}: #{$attrs}" if not attr and not $attrs.empty?
	$curPos+= 1	# but curNode remains on on THIS node; "return not NIL" not necessary: curPos+1 != NIL
end
def downLevel
	error "Nie ma poddrzewa w #{$curNode.name}" if $curNode.elements.count == 0
	$positions[$curLevel] = $curPos
	$levels[$curLevel] = $nodes
	$curLevel += 1
	$nodes = $curNode.elements
	$curPos = 1	# .elements od 1, nie od 0 !!!
	$maxPos = $nodes.count
	# curNode will be set by dzial | pole afterwards
end
def upLevel
	error "Nadmiarowe pola #{$nodes[$curPos..-1]}" if $curPos < $maxPos
	$curLevel -= 1
	$nodes = $levels[$curLevel]
	$maxPos = $nodes.count
	$curPos = $positions[$curLevel]
	# $curNode will be set by dzial|pole afterwards
end
def pole(name, attr=false, space:"tns", value:nil)
	error "Nie ma nastepnego pola #{name}" if $maxPos < $curPos
	$curNode = $nodes[$curPos]
	error "Ma byc pole #{name} jest #{$curNode.name}" if "#{space}:#{name}" != "#{$curNode.prefix}:#{$curNode.name}"
	$attrs = []
	$curNode.attributes.each {|key, val| $attrs << key}
	$attrNo = 0
	error "Musza byc atrybuty w polu #{name}" if attr and $attrs.empty?
	error "Nie ma byc atrybutow w polu #{name}: #{attrs}" if not attr and not $attrs.empty?
	$curPos += 1	# but curNode remains on THIS node
	error "To nie pole: #{name}: potomne #{$curNode.elements}" if $curNode.elements.count != 0
	if value
		error "Pole #{name} wartosc nie #{value} ale #{$curNode.text}" if $curNode.text != value
	else
		return $curNode.text
	end
end
def sPole(name, klucz=nil)
	$rsp[$nrSprz][klucz ? klucz : name] = pole name
end
def zPole(name, klucz=nil)
	$rza[$nrZak][klucz ? klucz : name] = pole name
end
def attr(name, value)
	error "Nie ma atrybutu #{name}: #{$attrs}" unless $attrs[$attrNo] == name
	error "#{$curNode.name} atrybut #{name} mial byc #{value} a nie #{$curNode.attributes[name]}" unless $curNode.attributes[name] == value
	$attrNo += 1
end
def noMoreAttr
	error "#{$curNode.name} nadmiarowe atrybuty #{attrs[$attrNo..-1]}" if $attrNo < $attrs.count
end
def ifPole(name, space:"tns", save:nil)	# pole MOZE BYC; w JPK_VAT nie ma atrybutow ani predefiniowanej wartosci; returns: JEST?, wartosc => save
	v = ""	# jezeli nie bedzie pola, to wartosc pusta - PO CO to potrzebne???
	return nil if $maxPos < $curPos	# nie ma nastepnego pola
	$curNode = $nodes[$curPos]
	return nil if "#{space}:#{name}" != "#{$curNode.prefix}:#{$curNode.name}"	# jest nastepne pole - ale inna nazwa
	error "Nie ma byc atrybutow w polu #{name}: #{attrs}" unless $attrs.empty?
	$curPos += 1	# but curNode remains on THIS node
	error "To nie pole: #{name}: potomne #{$curNode.elements}" if $curNode.elements.count != 0
	if save
		save.replace $curNode.text
	else
		return $curNode.text
	end
	
end
def ifNpole(name, space:"tns", save:nil)
	dokad = ""
	return nil unless ifPole name, space:space, save:dokad
	$naglowek[save ? save : name] = dokad
end
def ifSpole(name, save=nil)	# namespace - HERE always "tns" default
	dokad = ""
	return nil unless ifPole name, save:dokad
	$rsp[$nrSprz][save ? save : name] = dokad
end
def ifZpole(name, save=nil)	# namespace - HERE always "tns" default
	dokad = ""
	return nil unless ifPole name, save:dokad
	$rza[$nrZak][save ? save : name] = dokad
end
def ifSN(name)	# default namespace "tns", key == name
	dokad = ""
	return nil unless ifPole name, save:dokad
	$rsp[$nrSprz][name] = BigDecimal.new(dokad)
end
def ifSNN(name1, name2, typVAT="")
	return nil unless ifSN name1
	error "#{typVAT}: nie ma pola #{name2} po #{name1}" unless ifSN name2
end
def ifZN(name)	# default namespace "tns", key == name
	dokad = ""
	return nil unless ifPole name, save:dokad
	$rza[$nrZak][name] = BigDecimal.new(dokad)
end
def ifZNN(name1, name2, typVAT="")
	return nil unless ifZN name1
	error "#{typVAT}: nie ma pola #{name2} po #{name1}" unless ifZN name2
end
def vS(pole)
	return $rsp[$nrSprz][pole]
end
def pS(pole)
	return $rsp[$nrSprz][pole].to_s('F').reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end
def vZ(pole)
	return $rza[$nrZak][pole]
end
def pZ(pole)
	return $rza[$nrZak][pole].to_s('F').reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end
def sumS(*lista)
	s = BigDecimal.new(0)
	lista.each {|k| s+= ($rsp[0][k] || 0)}
	return s
end
def sumZ(*lista)
	s = BigDecimal.new(0)
	lista.each {|k| s+= ($rza[0][k] || 0)}
	return s
end
# JPK structure: program starts here ################################################
print "naglowek"
error "Ma byc XML typu 1.0 a nie #{doc.version}" if "1.0" != doc.version
error "Ma byc kodowanie UTF-8 a nie #{doc.encoding}" if doc.encoding != "UTF-8"
dzial "JPK", true	
downLevel
	dzial "Naglowek"
	downLevel
		pole "KodFormularza", true, value:"JPK_VAT"
			attr "kodSystemowy", "JPK_VAT (2)"
			attr "wersjaSchemy", "1-0"
			noMoreAttr
		pole "WariantFormularza", value:"2"
		jpkCel = pole "CelZlozenia"
			error "Cel zlozenia 1 lub 2, a nie #{jpkCel}" unless "12"[jpkCel]
		jpkData = pole "DataWytworzeniaJPK"
			tWytw = checkDate jpkData
		jpkOd = pole "DataOd"	# yyyy-mm-dd
			tOd = checkDate jpkOd
			mm = jpkOd[5..6]; yymm = jpkOd[0..3]+jpkOd[5..6]
			error "JPK mial byc od pierwszego, a nie od #{italian jpkOd}" unless jpkOd[8..9] == "01"
		jpkDo = pole "DataDo"
			tDo = checkDate jpkDo
			error "Data Do:#{italian jpkDo} przed Od:#{italian jpkOd}" if tDo < tOd
			error "JPK wytworzono #{italian jpkData} przed koncem okresu #{italian jpkDo}" if tWytw < tDo
			error "JPK za jeden m-c, a nie od #{italian jpkOd} do #{italian jpkDo}" unless jpkOd[0..7] == jpkDo[0..7]
			error "JPK za pelny m-c, a nie od #{italian jpkOd} do #{italian jpkDo}" if (tDo+60*60*24).strftime("%m") == mm
		pole "DomyslnyKodWaluty", value:"PLN"
		jpkKodUrzedu = pole "KodUrzedu"
			error "Kod urz.skarb. musi byc = 4 cyfry: #{jpkKodUrzedu}" unless jpkKodUrzedu =~ /^[1-9]\d{3}$/
# tablica kodow urzedow skarbowych
signal "JPK_VAT v 2 #{jpkCel=='1' ? 'Zlozenie':'Korekta'} za #{mm} z #{italian jpkData} #{jpkData[11..18]}: od #{italian jpkOd} do #{italian jpkDo} USK #{jpkKodUrzedu} w PLN\n"
$naglowek = {'KodFormularza'=>"JPK_VAT", 'kodSystemowy'=>"JPK_VAT (2)", 'wersjaSchemy'=>"1-0", 
	'WariantFormularza'=>"2", 'CelZlozenia'=>jpkCel, 'DataWytworzeniaJPK'=>jpkData, 'DataOd'=>jpkOd, 
'DataDo'=>jpkDo, 'DomyslnyKodWaluty'=>"PLN", 'KodUrzedu'=>jpkKodUrzedu}
	upLevel
	dzial "Podmiot1"
	downLevel
		dzial "IdentyfikatorPodmiotu"
		downLevel
			error "Podmiot1: #{blad}" unless plNip($naglowek["NIP"] = pole("NIP", space:"etd"))
			$naglowek["PelnaNazwa"] = pole "PelnaNazwa", space:"etd"
			error "REGON mam miec 9 cyfr: #{$naglowek['REGON']}" unless ifNpole("REGON", space:"etd") =~ /^[1-9]\d{8}$/
signal "#{$naglowek['PelnaNazwa']} NIP:#{$naglowek['NIP']}#{nonEmpty " REGON", "REGON"}"
		upLevel
		dzial "AdresPodmiotu"
		downLevel
			pole "KodKraju", value:"PL"
			ifNpole "Wojewodztwo"
			ifNpole "Powiat"
			ifNpole "Gmina"
			ifNpole "Ulica"
			ifNpole "NrDomu"
			ifNpole "NrLokalu"
			$naglowek['Miejscowosc'] = pole "Miejscowosc"
			error "Kod pocztowy format 99-999:#{$naglowek['KodPocztowy']}" unless ifNpole("KodPocztowy") =~ /^\d{2}-\d{3}$/
			ifNpole "Poczta"
signal "#{nonEmpty "ul.", 'Ulica'}#{nonEmpty " nr ", 'NrDomu'}#{nonEmpty " m ", 'NrLokalu'}"
signal "#{nonEmpty "", 'KodPocztowy'} #{$naglowek['Miejscowosc']}#{nonEmpty " poczta ", 'Poczta'}"
signal "#{nonEmpty "gm.", 'Gmina'}#{nonEmpty " pow.", 'Powiat'}#{nonEmpty " woj.", 'Wojewodztwo'}"
		upLevel
	upLevel
	$nrSprz = 0
	while ifDzial "SprzedazWiersz", true
		attr "typ", "G"
		noMoreAttr
		downLevel
		if $nrSprz==0
			rs = File.new("JSP"+yymm+".log", "w"); $out = rs
print ",Sprzedaz..."
signal "(C)PLURIX(R) - analiza JPK(2): RSP za #{mm}\n"
signal "#{jpkCel=='1' ? 'Zlozenie':'Korekta'} za #{mm} z #{italian jpkData} #{jpkData[11..18]}: od #{italian jpkOd} do #{italian jpkDo}\n"
			$rsp = Array.new(1) {Hash.new}
			$rsp[0] = $naglowek
		end
		$nrSprz += 1
		$rsp[$nrSprz] = Hash.new
		pole "LpSprzedazy", value:$nrSprz.to_s
		signal $blad unless ueNIP(sPole "NrKontrahenta", 'nipNabywc')
		sPole "NazwaKontrahenta", 'nabywca'
# nazwa firmy: nazwa.gsub /\n/ " "	# zamien NL na SP
		sPole "AdresKontrahenta", 'siedziba'
		sPole "DowodSprzedazy", 'numerFry'
		sPole "DataWystawienia", 'dataFry'
			tFS = checkDate vS('dataFry')
signal "#{$nrSprz}) #{vS 'nipNabywc'} #{vS 'nabywca'} #{vS 'siedziba'} #{vS 'numerFry'} #{italian vS('dataFry')}", ""
		error "Data Sprzedazy #{italian vS('dataSprz')} tylko, gdy rozna od Daty Fry #{italian vS('dataFry')}" if vS('dataFry') == ifSpole("DataSprzedazy", 'dataSprz')
			tDS = checkDate vS('dataSprz') if vS 'dataSprz'
		ifSN "K_10"	#kraj ZW
		ifSN "K_11"	#poza krajem
		ifSN "K_12"	#- w tym: do VAT-UE
		ifSN "K_13"	#kraj 0%
		ifSN "K_14"	#- w tym: zwrot VAT podroznym
		error "Stawka 5% - roznica ponad 1.- PLN: netto #{pS 'K_15'} VAT #{pS 'K_16'}" if ifSNN("K_15", "K_16", "Kraj 5%") and (vS('K_15')*0.05-vS('K_16')).abs > 1
		error "Stawka 7%|8% - roznica ponad 1.- PLN: netto #{pS 'K_17'} VAT #{pS 'K_18'}" if ifSNN("K_17", "K_18", "Kraj 7%|8%") and (vS('K_17')*0.08-vS('K_18')).abs > 1 and (vS('K_17')*0.07-vS('K_18')).abs > 1
		error "Stawka 22%|23% - roznica ponad 1.- PLN: netto #{pS 'K_19'} VAT #{pS 'K_20'}" if ifSNN("K_19", "K_20", "Kraj 22%|23%") and (vS('K_19')*0.23-vS('K_20')).abs > 1 and (vS('K_19')*0.22-vS('K_20')).abs > 1
		ifSN "K_21"	#WDT
		ifSN "K_22"	#export
		ifSNN "K_23", "K_24", "WNT"
		ifSNN "K_25", "K_26", "import towarow proc.uproszcz.(art. 33a)"
		ifSNN "K_27", "K_28", "import uslug oprocz VAT-UE (art. 28b)"
		ifSNN "K_29", "K_30", "import uslug VAT-UE (art. 28b)"
		ifSN "K_31" #kraj odwr.obc. - dotawca (art. 17 ust. 1 pkt 7|8) wrazliwe
		ifSNN "K_32", "K_33", "kraj odwr.obc. - nabywca (art. 17 ust. 1 pkt 5) od pozakrajowego niezarejestrowanego"
		ifSNN "K_34", "K_35", "kraj odwr.obc. - nabywca (art. 17 ust. 1 pkt 7|8) wrazliwe"
		ifSN "K_36" # rem.likwidacyjny (art. 14 ust. 5)
		ifSN "K_37" # zwrot odliczenia za kasy (art. 111 ust. 6
		ifSN "K_38" # WNT aut wplac.do USk (art. 103 ust. 3|4)
		ifSN "K_39" # WNT paliw wplac.do USk (art. 103 ust. 5a i 5b)
($rsp[$nrSprz].keys.grep /K_/).each {|k| signal ";#{k}=#{pS k}", ""}
signal ""
		upLevel
	end
	if $nrSprz > 0
		(1..$nrSprz).each {|i| ($rsp[i].keys.grep /K_/).each {|k| $rsp[0][k]||=BigDecimal.new(0); $rsp[0][k]+=$rsp[i][k] if $rsp[i][k]}}
		$rsp[0]['sprzR'] = sumS 'K_10', 'K_11', 'K_13', 'K_15', 'K_17', 'K_19', 'K_21', 'K_22', 'K_23', 'K_25', 'K_27', 'K_29', 'K_31', 'K_32', 'K_34'
		$rsp[0]['sprzV'] = sumS('K_16', 'K_18', 'K_20', 'K_24', 'K_26', 'K_28', 'K_30', 'K_33', 'K_35', 'K_36', 'K_37') - sumS('K_38', 'K_39')
nr = $nrSprz; $nrSprz = 0	# na potrzeby pS - ¿eby bralo z podsumowania w $rsp[0]
signal "RSP: #{nr} dokumentow: NETTO=#{pS 'sprzR'} VAT=#{pS 'sprzV'}"
signal "======== KONIEC RSP#{yymm} ======#{Time.now.strftime "%d-%m-%Y %H:%M:%S"}======"
		rs.close; $out = $log
signal "RSP: #{nr} dokumentow: NETTO=#{pS 'sprzR'} VAT=#{pS 'sprzV'}"
$nrSprz = nr	# odkrecamy
		db = File.new("JS#{yymm}.rb", 'w'); db.print "$rsp="; db.puts $rsp; db.close	#dump $rsp table for 'source'
		dzial "SprzedazCtrl"
		downLevel
			pole "LiczbaWierszySprzedazy", value:$nrSprz.to_s
			pole "PodatekNalezny", value:$rsp[0]['sprzV'].to_s('F')
		upLevel
	end
	$nrZak = 0
	while ifDzial "ZakupWiersz", true
		attr "typ", "G"
		noMoreAttr
		downLevel
		if $nrZak==0
			rz = File.new("JZA#{yymm}.log", "w"); $out = rz
print ", Zakupy..."
signal "(C)PLURIX(R) - analiza JPK(2): RZA za #{mm}\n"
signal "#{jpkCel=='1' ? 'Zlozenie':'Korekta'} za #{mm} z #{italian jpkData} #{jpkData[11..18]}: od #{italian jpkOd} do #{italian jpkDo}\n"
			$rza = Array.new(1) {Hash.new}
			$rza[0] = $naglowek
		end
		$nrZak += 1
		$rza[$nrZak] = Hash.new
		pole "LpZakupu", value:$nrZak.to_s
		signal $blad unless ueNIP(sPole "NrDostawcy", 'nipSprzed')
		zPole "NazwaDostawcy", 'sprzedawca'
		zPole "AdresDostawcy", 'siedziba'
		zPole "DowodZakupu", 'numerFry'
		zPole "DataZakupu", 'dataObow'
			tFZ = checkDate vZ('dataObow')
signal "#{$nrZak}) #{vZ 'nipSprzed'} #{vZ 'sprzedawca'} #{vZ 'siedziba'} #{vZ 'numerFry'} #{italian vZ('dataObow')}", ""
		tDZ = checkDate vZ('DataWplywu') if  ifZpole("DataWplywu")
		ifZNN "K_43", 'K_44', "nabycie sr.trw."
		ifZNN "K_45", "K_46", "nabycia pozostale"
		ifZN "K_47"	#kor.nabycia sr.trw.
		ifZN "K_48"	#kor.nabycia pozostale
		ifZN "K_49"	#kor.VAT 150 dni na minus (art. 89b ust. 1)
		ifZN "K_50"	#kor.VAT 150 dni na plus (art. 89b ust. 4)
($rza[$nrZak].keys.grep /K_/).each {|k| signal ";#{k}=#{pZ k}", ""}
signal ""
		upLevel
	end
	if $nrZak > 0
		(1..$nrZak).each {|i| ($rza[i].keys.grep /K_/).each {|k| $rza[0][k]||=BigDecimal.new(0); $rza[0][k]+=$rza[i][k] if $rza[i][k]}}
		$rza[0]['zakR'] = sumZ 'K_43', 'K_45'
		$rza[0]['zakV'] = sumZ 'K_44', 'K_46', 'K_47', 'K_48', 'K_49', 'K_50'	# nie ma byc aby K_49 na MINUS???
nr = $nrZak; $nrZak = 0	# na potrzeby pZ - ¿eby bralo z podsumowania w $rza[0]
signal "RZA: #{nr} dokumentow: NETTO=#{pZ 'zakR'} VAT=#{pZ 'zakV'}"
signal "======== KONIEC RZA#{yymm} ======#{Time.now.strftime "%d-%m-%Y %H:%M:%S"}======"
		rz.close; $out = $log
signal "RZA: #{nr} dokumentow: NETTO=#{pZ 'zakR'} VAT=#{pZ 'zakV'}"
$nrZak = nr	# odkrecamy
		db = File.new("JZ#{yymm}.rb", 'w'); db.print "$rza="+$rza.inspect; db.close	#marshall $rza table
		dzial "ZakupCtrl"
		downLevel
			pole "LiczbaWierszyZakupow", value:$nrZak.to_s
			pole "PodatekNaliczony", value:$rza[0]['zakV'].to_s('F')
		upLevel
	end
upLevel	
print ", VAT-7..."
vat7 = Hash.new
("K_10".."K_39").each {|k| vat7[k] = ($rsp[0][k] || 0).round}
vat7["K_40"] = $rsp[0]['sprzR'].round; vat7["K_41"] = $rsp[0]['sprzV'].round
("K_43".."K_50").each {|k| vat7[k] = ($rza[0][k] || 0).round}
db = File.new("V7#{yymm}.rb", "w"); db.print "vat7="+vat7.inspect; db.close
# report: JV7 za yymm
$vat7 = vat7	# simplest way to circumvent Ruby's idiosyncrasy about local scopes
def v(n)
	return " "*11 if $vat7[n] == 0
	return (" "*11 + $vat7[n].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse)[-11,11]
end
v7dekl = File.new("JV7"+yymm+".prn", "w")
v7dekl.puts "#{($naglowek['PelnaNazwa']+" "*11)[0,11]} Deklaracja VAT-7 (wz.17) za #{mm}/#{yymm[0,4]}   (C) PLURIX, JKL, Katowice 1993"
v7dekl.puts ""
v7dekl.puts "A. MIEJSCE I CEL ZLOZENIA                               7. #{jpkCel=='1' ? 'X zlozenie  ':'  zlozenie X'} korekta"
v7dekl.puts ""
v7dekl.puts "C. ROZLICZENIE TRANSAKCJI PODLEGAJACYCH OPODATKOWANIU ORAZ PODATKU NALEZNEGO"
v7dekl.puts "     A TAKZE POZA KRAJEM                PODSTAWA OPOD. PODATEK NALEZNY"
v7dekl.puts "  1. Kraj zwolniony                      10#{v "K_10"} -------------"
v7dekl.puts "  2. Poza krajem                         11#{v "K_11"} -------------"
v7dekl.puts "  2a.w tym: (art.100ust.1pkt4)           12#{v "K_12"} -------------"
v7dekl.puts "  3. Kraj  0%                            13#{v "K_13"} -------------"
v7dekl.puts "  3a.w tym: zwrot podroznym (art.129)    14#{v "K_14"} -------------"
v7dekl.puts "  4. Kraj  superobnizona 3%/5%           15#{v "K_15"} 16#{v "K_16"}"
v7dekl.puts "  5. Kraj  obnizona 7%/8%                17#{v "K_17"} 18#{v "K_18"}"
v7dekl.puts "  6. Kraj podstawowa 22%/23%             19#{v "K_19"} 20#{v "K_20"}"
v7dekl.puts "  7. W Dostawa T                         21#{v "K_21"} -------------"
v7dekl.puts "  8. Eksport                             22#{v "K_22"} -------------"
v7dekl.puts "  9. W Nabycie T               787 238   23#{v "K_23"} 24#{v "K_24"}"
v7dekl.puts " 10. Import towarow proc.uprosz.art.33a  25#{v "K_25"} 26#{v "K_26"}"
v7dekl.puts " 11. Import uslug oprocz art.28b         27#{v "K_27"} 28#{v "K_28"}"
v7dekl.puts " 12. Imp.usl. od podatn. z UE/C art.28b  29#{v "K_29"} 30#{v "K_30"}"
v7dekl.puts " 13. Sprzedaz wrazliwych (odwr.obciaz)   31#{v "K_31"} -------------"
v7dekl.puts " 14. Samoopodatk.nabycia tow/uslug       32#{v "K_32"} 33#{v "K_33"}"
v7dekl.puts " 15. Nabycie wrazliwych (odwr.obciaz)    34#{v "K_34"} 35#{v "K_35"}"
v7dekl.puts " 16. Nalezny z remanentu likwidacyjnego (art.14 ust.5) 36#{v "K_36"}"
v7dekl.puts " 17. Zwrot ulgi za kasy (art. 111 ust. 6)              37#{v "K_37"}"
v7dekl.puts " 18. z l.9 p.24: WNT nowych aut juz zaplac(art103ust3) 38#{v "K_38"}"
v7dekl.puts " 19. WNT paliw juz zaplacony (art. 103 ust. 5a i 5b)   39#{v "K_39"}"
v7dekl.puts "  RAZEM NALEZNY (1..17-17-19)            40#{v "K_40"} 41#{v "K_41"}"
v7dekl.puts "D. ROZLICZENIE PODATKU NALICZONEGO"
v7dekl.puts "D1. PRZENIESIENIA                                      PTU DO ODLICZENIA"
v7dekl.puts "  Nadwyzka z poprz.deklaracji [61]  0                  42 xxxxxxxxxx"
v7dekl.puts "...................................................................."
v7dekl.puts "D2. NABYCIE TOWAROW I USLUG ORAZ PODATEK NALICZONY Z UWZGLEDNIENIEM KOREKT"
v7dekl.puts " 1. Nabycie sr.trwalych                  43#{v "K_43"} 44#{v "K_44"}"
v7dekl.puts " 2. Nabycia pozostale                    45#{v "K_45"} 46#{v "K_46"}"
v7dekl.puts "D3. PODATEK NALICZONY DO ODLICZENIA"
v7dekl.puts "  Korekta naliczonego od sr.trwalych                   47#{v "K_47"}"
v7dekl.puts "  Korekta naliczonego od pozostalych                   48#{v "K_48"}"
v7dekl.puts "  Korekta naliczonego od niezaplac. 150 dni (a.89b u1) 49#{v "K_49"}"
v7dekl.puts "  Korekta naliczonego od ZAPLACONYCH 150 dni (a89b u4) 50#{v "K_50"}"
v7dekl.puts " RAZEM NALICZONY DO ODLICZENIA [42+44+46+47+48+49+50]  51           "
v7dekl.puts "E. OBLICZENIE WYSOKOSCI ZOBOWIAZANIA PODATKOWEGO LUB KWOTY ZWROTU"
v7dekl.puts "  Odliczenie za kasy na biezacy miesiac {max[41-51]}   52           "
v7dekl.puts "  Zaniechanie poboru {max[41-51-52]}                   53           "
v7dekl.puts "  Kwota do wplaty do Urzedu Skarbowego [41-51-52-53]   54           "
v7dekl.puts "  Zwrot za kasy na dany miesiac                        55           "
v7dekl.puts "  Nadwyzka PTU naliczonego nad naleznym [51-41+55]     56           "
v7dekl.puts "    Do zwrotu na rachunek bankowy (w tym w terminie:)  57           "
v7dekl.puts "    25dni: 58            60dni: 59            180 dni: 60           "
v7dekl.puts "    Do przeniesienia na nast.okres [56-57]             61           "
v7dekl.puts "F. INFORMACJE DODATKOWE   Wykonywal w ciagu miesiaca czynnosci:"
v7dekl.puts "   62              63          64          65      "
v7dekl.puts "G. INFORMACJA O ZALACZNIKACH (tylko, gdy 57 ZWROT > 0)"
v7dekl.puts " 66.Wniosek o zwrot:                 67. Szybki zwrot:                "
v7dekl.puts " Ulga zle dlugi 68 NIE  Ilosc zal. ZD 69   "
v7dekl.puts "======================================================================"
v7dekl.puts "  #{Time.now.strftime "%d-%m-%Y %H:%M:%S"}      KONIEC VAT-7:#{yymm}    "
v7dekl.close

wdt = Hash.new unless vat7["K_21"] == 0
wnt = Hash.new unless vat7["K_23"] == 0 && vat7["K_24"] == 0
usl = Hash.new unless vat7["K_12"] == 0
rev = Hash.new unless vat7["K_31"] == 0
(1..$nrSprz).each do |i|
	nip = $rsp[i]["nipNabywc"]
	if $rsp[i]["K_21"] then wdt[nip] ||= BigDecimal.new(0); wdt[nip] += $rsp[i]["K_21"] end
	if $rsp[i]["K_23"] || $rsp[i]["K_24"] then wnt[nip] ||= BigDecimal.new(0); wnt[nip] += $rsp[i]["K_23"] end
	if $rsp[i]["K_12"] then usl[nip] ||= BigDecimal.new(0); usl[nip] += $rsp[i]["K_12"] end
	if $rsp[i]["K_31"] then rev[nip] ||= {"nabywca"=> $rsp[i]["nabywca"], "kwota"=>BigDecimal.new(0)}; rev[nip]["kwota"] += $rsp[i]["K_31"] end
end
if vat7["K_21"] != 0 || vat7["K_23"] != 0 || vat7["K_24"] != 0 || vat7["K_12"] != 0
	vue = File.new("JVUE#{yymm}.prn", "w")
print ", VAT-UE..."
vue.puts "#{($naglowek['PelnaNazwa']+" "*11)[0,11]} VAT-UE deklaracja WNT/WDT za #{mm}/#{yymm[0,4]} (C) PLURIX, JKL, Katowice 1993"
	if vat7["K_21"] != 0
		suma = 0; ile = 0; i = 0
vue.puts""
vue.puts"C.INFORMACJA O WEWNATRZWSPOLNOTOWYCH DOSTAWACH TOWAROW   "
vue.puts"    KR     NIP-UE          KWOTA      3"
vue.puts"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		wdt.each do |k, v|
			ile = v.round; suma += ile; i+= 1
		vue.puts"#{(' '+i.to_s)[-2,2]}  #{k[0,2]} #{(k[2,12]+' '*12)[0,12]}     #{(' '*11 + ile.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse)[-11,11]}   "
		end
		wdt["suma"] = suma
vue.puts"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
vue.puts"                        #{(' '*11 + suma.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse)[-11,11]}   "
	end
	if vat7["K_23"] != 0 || vat7["K_24"] != 0
		suma = 0; ile = 0; i = 0
vue.puts"                                       "
vue.puts"D. INFORMACJA O WEWNATRZWSPOLNOTOWYCH NABYCIACH TOWAROW  "
vue.puts"    KR     NIP-UE          KWOTA      3"
vue.puts"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		wnt.each do |k, v|
			ile = v.round; suma += ile; i+= 1
		vue.puts"#{(' '+i.to_s)[-2,2]}  #{k[0,2]} #{(k[2,12]+' '*12)[0,12]}     #{(' '*11 + ile.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse)[-11,11]}   "
		end
		wnt["suma"] = suma
vue.puts"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
vue.puts"                        #{(' '*11 + suma.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse)[-11,11]}   "
	end
	if vat7["K_12"] != 0
		suma = 0; ile = 0; i = 0
vue.puts"                                       "
vue.puts"E.INFORMACJA O WEWNATRZWSPOLNOTOWYM SWIADCZENIU USLUG    "
vue.puts"    KR     NIP-UE          KWOTA      3"
vue.puts"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		usl.each do |k, v|
			ile = v.round; suma += ile; i+= 1
		vue.puts"#{(' '+i.to_s)[-2,2]}  #{k[0,2]} #{(k[2,12]+' '*12)[0,12]}     #{(' '*11 + ile.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse)[-11,11]}   "
		end
		usl["suma"] = suma
vue.puts"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
vue.puts"                        #{(' '*11 + suma.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse)[-11,11]}   "
	end
vue.puts"                                       "
vue.puts "======================================================================"
vue.puts "  #{Time.now.strftime "%d-%m-%Y %H:%M:%S"}  KONIEC VAT-UE:#{yymm}    "
	vue.close
end
if vat7["K_31"] != 0
	v27 = File.new("JV27#{yymm}.prn", "w")
print ", VAT-27..."
	suma = 0; ile = 0; i = 0
v27.puts "#{($naglowek['PelnaNazwa']+" "*11)[0,11]} VAT-27 deklaracja wrazliwe za #{mm}/#{yymm[0,4]} (C) PLURIX, JKL, Katowice 1993"
v27.puts " "
v27.puts "C. INFORMACJA O DOSTAWACH TOWAROW"
v27.puts "Lp zmiana       FIRMA                      NIP       KWOTA"
v27.puts "================================================================"
rev.keys.each do |k| 
	ile = rev[k]["kwota"].round; suma += ile; i+= 1
	v27.puts"#{(' '+i.to_s)[-2,2]}        #{(rev[k]["nabywca"]+' '*30)[0,30]} #{k} #{(' '*11 + ile.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse)[-11,11]} "
end
v27.puts "================================================================"
v27.puts"                                                    #{(' '*11 + suma.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse)[-11,11]}   "
v27.puts "======================================================================"
v27.puts "  #{Time.now.strftime "%d-%m-%Y %H:%M:%S"}  KONIEC VAT-27:#{yymm}    "
	v27.close
	
end

# sprawdz poprawnosc naglowek, RSP i RZA	
# RSP: test ciaglosci numeracji faktur (statystyczny test sekwencyjnoœci numerów)
# RSP: odwr.obc. (WNT, krajowe) powinno byc tez w RZA (ale nie musi - opoznienie w otrzymaniu faktury) K_23, K_25, K_27, K_29, K_32, K_34
# RZA: jezeli nry faktur sa kolejno rosnace - to nie sa numery od dostawcy, ale wewnetrzne z ksiegowosci
# RZA: jezeli ten sam numer fry wystepuje kilkakrotnie (dla tego samego NIP przedawcy) - a jeszcze z tymi samymi kwotami, to pewnie jest ujeta wielokrotnie ta sama fra
# VAT-UE: K_21 = WDT, K_23 = WNT, K_12 = us³ugi
# VAT-27: K_31
signal "========== Koniec analizy =========#{Time.now.strftime "%d-%m-%Y %H:%M:%S"}======"
$out.close
puts "\n"
print "==== OK: sukces===== aby zamknac - wcisnij ENTER:"
gets
# exit
rescue Exception => e
	puts "\n"
	puts e.backtrace.inspect
	$log.puts "\n"; $log.puts e.backtrace.inspect; $log.puts "\n"
	error e.message
end
# doc.root_node
# doc.xml_decl	# <?xml version='1.0' encoding='UTF-8'?>
# doc.elements << el # albo doc.elements << Element.new("<fieldname>"); returns added element
# naglowek = root.elements[1] # index -> child elements (starting from ONE, not zero)
# naglowek.elements[1].attributes['wersjaSchemy'] # attrname = key, attrvalue = value
# root.elements["tns:Podmiot1"] # XPath -> child elements; index [1] == XPath [*[1]]
# root.elements["tns:SprzedazWiersz[3]/tns:K_19"] # tak¿e ["<fieldname>[@<attrname>='<attrvalue>']"]
# root.each_element('//tns:ZakupWiersz') {|zakup| puts zakup.elements['tns:K_45']} # each_element == elements.each
# doc.add_element("<fieldname>", {"<atrrname>" => "<attrvalue>"}) # mo¿e byæ tylko <fieldname>, albo ca³a lista "hash" par atrybutów nazwa => wartoœæ
# el = Element.new("<fieldname>")
# el.add_element("<child-fieldname>") # returns added element
# el.elements["<child-fieldname>"].text = "<fieldvalue>"
# albo el.text = "<value>"  # if no childrens
# albo el.add_text("<value>")
# el.add_attribute("<atrrname", "<attrvalue>")
# doc.insert_before("<XPath>", el) # tak¿e insert_after
# el.delete_attribute("<attrname>") # returns removed attribute
# el.delete_element("//tns:SprzedazCtrl") # lub (1)-element index lub Element object
# el.next_element # or NIL | previous_element
# el.node_type :element | :document
# el.parent # or NIL
# el.size ???
# el.cdatas() | el.comments()	# immutable array of all such children
# el.has_attributes? | el.has_elements?	| el.has_text? # true if has any (also grand-child)
# el.namespace	# returns URI , not prefix (el.prefix)!!! el.prefixes returns ALL defined namespaces
# require 'rexml/streamlistener' # STREAM mode: nie ma XPath !