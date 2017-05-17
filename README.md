# JPK_VAT
Polish SAF-T (Standard Audit File for Tax) verifier.
JPK_VAT(2) was introduced from January 1, 2017 by Polish Ministry of Finance to most companies in Poland. XSD specification was published for XML monthly reporting files for VAT registers. There're six other JPK file types (for other accounting books), which are not mandatory (only on request from tax authority starting from July 1, 2018). 
This program checks JPK_VAT(2) file prepared elsewhere for syntax correctness and some obvious semantic errors (miised or duplicated data, wrong entries, inconsistencies betw. registers and so on); prints monthly tax statements (VAT-7, VAT-UE, VAT-27) based on analysed data. 
The language chosen is plain Ruby (without Rails) with appropriate gems (BigDecimal, REXML,...).
# Quick Start Guide
JPK_VAT.rb is the (complete) Ruby program, JPK_VAT.exe is Windows executable (created by OCRA).
# License
JPK_VAT is licensed under the GNU AGPLv3 license.
# Copyright
© 2017 PLURIX, K-ce
