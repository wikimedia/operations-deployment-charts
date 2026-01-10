import sys

from . import chart

ch = chart.Chart(sys.argv[1])
mfsts = ch.render()

if len(sys.argv) > 2:
    fname = sys.argv[2]

    cms = mfsts.find_all( { "kind": "ConfigMap" } )

    for cm in cms:
        data = cm.get_yaml(["data", fname])

        if data:
            print( data.dump() )
else:
    print( mfsts.dump() )