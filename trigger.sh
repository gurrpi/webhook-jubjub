#!/bin/sh

export GH_TOKEN="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"
#Proceed only when status field has changed
changed_field_node_id=$5

# type: ProjectV2SingleSelectField, name: Status
expected_field_node_id="PVTSSF_lADOA6x_vs4ALj8tzgHX2Gw"
if [[ "$changed_field_node_id" = "$expected_field_node_id" ]]
then
    echo "Status change detected"

    # Query the detail of GitHub project item
    gh api graphql -f query='
    query($id: ID!){
        node(id: $id) {
            ... on ProjectV2Item {
                createdAt
                fieldValueByName(name: "Status") {
                    ... on ProjectV2ItemFieldSingleSelectValue {
                        name
                    }      
                }
                content {
                    ... on DraftIssue {
                        title
                    }
                    ... on Issue {
                        title
                    }
                    ... on PullRequest {
                        title
                    }
                }
            }
        }
    }' -f id=$1 > query_result.json

    # if query_result.json is Blocked then trigger


    expected_fieldValue_blocked="🛑 Blocked"
    expected_fieldValue_inProgress="🏗 In Progress"
    expected_fieldValue_PRreadyForCR="👀 PR Ready for CR"
    expected_fieldValue_done="✅ Done"


    fieldValue=$(jq --raw-output '.data.node.fieldValueByName.name' query_result.json)

    echo

    if [[ "$fieldValue" = "$expected_fieldValue" || "$fieldValue" = "$expected_fieldValue_inProgress" || "$fieldValue" = "$expected_fieldValue_PRreadyForCR" ||"$fieldValue" = "$expected_fieldValue_done"  ]]
    then
        echo "Field value: \"$fieldValue\" should notified to TG chat"
        echo "Triggering ..."

        # Trigger GitHub Actions to push TG
        sender=$2
        title=$(jq --raw-output '.data.node.content.title' query_result.json)
        createdAt=$(jq --raw-output '.data.node.createdAt' query_result.json)
        updatedAt=$3
        itemId=$4

        curl -L \
            -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer "$GH_TOKEN""\
            -H "X-GitHub-Api-Version: 2022-11-28" \
            https://api.github.com/repos/gurrpi/webhook-jubjub/actions/workflows/tg-push.yml/dispatches \
            -d "{\"ref\":\"master\",\"inputs\":{\"title\": \"$title\", \"createdAt\": \"$createdAt\", \"updatedAt\": \"$updatedAt\", \"sender\": \"$sender\", \"itemId\": \"$itemId\", \"fieldValue\": \"$fieldValue\"}}"
    else
        echo "Abort: we are not interested in $fieldValue"
    fi
else
    echo "Abort: we are not interested in anything other than state changes"
fi