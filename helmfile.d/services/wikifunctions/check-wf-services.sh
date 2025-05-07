#!/bin/bash

# This is a script that runs a series of standard tests against the Wikifunctions
# back-end service, to quickly assess basic functionality and whether it is working
# as expected during deployments.

function testServices {
        echo -n ' - '
        printf %-20s "$1"
        echo -n ': '
        command='{"zobject":'
        command+="${3//_/ }"
        command+=',"doValidate":false}'
        response=$(curl $2 --silent --header "Content-type: application/json" -X POST --data $command)
        if grep -q -v "Z22" <<< "$response"; then
                echo -e '\e[31mFailed response\e[0m:' $response
                return
        fi

        if [[ $5 == 'lexeme' ]]
                then
                value=$(echo $response | jq '.Z22K1.Z6005K2.Z12K1[1].Z11K2')
                else
                value=$(echo $response | jq '.Z22K1')
        fi

        if [[ $value == $4 ]]
                then
                echo -ne "\e[32m"
                else
                echo -ne "\e[31m"
        fi
        printf %-10s "$value"
        echo -ne "\e[0m – "
        timing=$(echo $response | jq '.Z22K2.K1[] | select(.K1 == "orchestrationDuration") | .K2' | tr -dc '0-9')
        if [[ $timing -lt 100 ]]
                then
                echo -ne "\e[32m"
                else
                if [[ $timing -lt '500' ]]
                        then
                        echo -ne "\e[33m"
                        else
                        if [[ $timing -lt '1000' ]]
                                then
                                echo -ne "\e[91m"
                                else
                                echo -ne "\e[31m"
                        fi
                fi
        fi
        echo -e $timing ms"\e[0m"
}

basicecho='{"Z1K1":"Z7","Z7K1":"Z801","Z801K1":"foo"}'
jsaddcall='{"Z1K1":"Z7","Z7K1":{"Z1K1":"Z8","Z8K1":["Z17",{"Z1K1":"Z17","Z17K1":"Z6","Z17K2":{"Z1K1":"Z6","Z6K1":"Z400K1"},"Z17K3":{"Z1K1":"Z12","Z12K1":["Z11"]}},{"Z1K1":"Z17","Z17K1":"Z6","Z17K2":{"Z1K1":"Z6","Z6K1":"Z400K2"},"Z17K3":{"Z1K1":"Z12","Z12K1":["Z11"]}}],"Z8K2":"Z1","Z8K3":["Z20"],"Z8K4":["Z14",{"Z1K1":"Z14","Z14K1":"Z400","Z14K3":{"Z1K1":"Z16","Z16K1":"Z600","Z16K2":"function\tZ400(Z400K1,Z400K2){return(parseInt(Z400K1)+parseInt(Z400K2)).toString();}"}}],"Z8K5":"Z400"},"Z400K1":"15","Z400K2":"18"}'
strngjoin='{"Z1K1":"Z7","Z7K1":"Z10000","Z10000K1":"foo","Z10000K2":"bar"}'
lexemeone='{"Z1K1":"Z7","Z7K1":"Z6825","Z6825K1":{"Z1K1":"Z6095","Z6095K1":"L2"}}'

# DISABLED: The necessary whitespace breaks the funky curl we do above, so we can't test this this way
#pyaddcall='{"Z1K1":"Z7","Z7K1":{"Z1K1":"Z8","Z8K1":["Z17",{"Z1K1":"Z17","Z17K1":"Z6","Z17K2":{"Z1K1":"Z6","Z6K1":"Z400K1"},"Z17K3":{"Z1K1":"Z12","Z12K1":["Z11"]}},{"Z1K1":"Z17","Z17K1":"Z6","Z17K2":{"Z1K1":"Z6","Z6K1":"Z400K2"},"Z17K3":{"Z1K1":"Z12","Z12K1":["Z11"]}}],"Z8K2":"Z1","Z8K3":["Z20"],"Z8K4":["Z14",{"Z1K1":"Z14","Z14K1":"Z400","Z14K3":{"Z1K1":"Z16","Z16K1":{"Z1K1":"Z61","Z61K1":"Z610"},"Z16K2":"def\tZ400(Z400K1,Z400K2):\n\treturn_str(int(Z400K1)+int(Z400K2))"}}],"Z8K5":"Z400"},"Z400K1":"5","Z400K2":"8"}'
#testServices "Python add" $cluster $pyaddcall '"13"'

echo -e "\e[97mStaging\e[0m tests:"
cluster="https://wikifunctions.k8s-staging.discovery.wmnet:30443/1/v1/evaluate/"
testServices "Basic echo" $cluster $basicecho '"foo"'
testServices "JavaScript add" $cluster $jsaddcall '"33"'
testServices "String join" $cluster $strngjoin '"foobar"'
testServices "Lexeme fetch" $cluster $lexemeone '"first"' lexeme

echo -e "\n\e[97mProduction\e[0m tests:"
cluster="https://wikifunctions.discovery.wmnet:30443/1/v1/evaluate/"
testServices "Basic echo" $cluster $basicecho '"foo"'
testServices "JavaScript add" $cluster $jsaddcall '"33"'
testServices "String join" $cluster $strngjoin '"foobar"'
testServices "Lexeme fetch" $cluster $lexemeone '"first"' lexeme
