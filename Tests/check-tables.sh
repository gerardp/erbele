#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
# Load the production table subtrees with isolated array controllers instead of the application database.
python3 - "$test_dir" <<'PY'
from pathlib import Path
from copy import deepcopy
from xml.etree import ElementTree as ET
import subprocess, sys
for path in [Path('Resources/FRAProject.xib'), Path('Resources/Base.lproj/FRACommands.xib'), Path('Resources/Base.lproj/FRASnippets.xib')]:
    source = ET.parse(path).getroot()
    parents = {child: parent for parent in source.iter() for child in parent}
    for table in source.iter('tableView'):
        if table.get('customClass') != 'FRATableView':
            continue
        assert table.get('viewBased') == 'YES'
        scroll = parents[parents[parents[table]]]
        assert scroll.tag == 'scrollView'
        controller_id = table.find("connections/binding[@name='content']").get('destination')
        doc = ET.Element('document', source.attrib)
        doc.append(deepcopy(source.find('dependencies')))
        objects = ET.SubElement(doc, 'objects')
        ET.SubElement(objects, 'customObject', id='-2', customClass='NSObject', userLabel="File's Owner")
        ET.SubElement(objects, 'customObject', id='-1', customClass='FirstResponder')
        ET.SubElement(objects, 'arrayController', id=controller_id)
        window = ET.SubElement(objects, 'window', title='Table migration check', id='check-window')
        ET.SubElement(window, 'windowStyleMask', key='styleMask', titled='YES', closable='YES', resizable='YES')
        ET.SubElement(window, 'rect', key='contentRect', x='0', y='0', width='800', height='300')
        content = ET.SubElement(window, 'view', key='contentView', id='check-content')
        ET.SubElement(content, 'rect', key='frame', x='0', y='0', width='800', height='300')
        subviews = ET.SubElement(content, 'subviews')
        subviews.append(deepcopy(scroll))
        subviews[0].find('rect').attrib.update(x='0', y='0', width='800', height='300')
        name = Path(sys.argv[1]) / (path.stem + '-' + table.get('id'))
        ET.ElementTree(doc).write(str(name)+'.xib', encoding='utf-8', xml_declaration=True)
        subprocess.run(['xcrun', 'ibtool', '--errors', '--compile', str(name)+'.nib', str(name)+'.xib'], check=True, stdout=subprocess.DEVNULL)
PY
xcrun clang -fobjc-arc -fmodules -mmacosx-version-min=11.0 -framework Cocoa \
    -I Sources/Classes -I Sources/TextView -I Sources/LineNumbers -I Other \
    -include Sources/Classes/FRAStandardHeader.h Tests/check-tables.m \
    Sources/Classes/FRATableView.m Sources/Classes/FRADocumentsListCell.m \
    -o "$test_dir/check-tables"
"$test_dir/check-tables" "$test_dir"
