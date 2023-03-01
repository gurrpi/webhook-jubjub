#!/bin/sh



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
expected_fieldValue="🛑 Blocked"
fieldValue=$(jq --raw-output '.data.node.fieldValueByName.name' query_result.json)

echo

if [[ "$fieldValue" = "$expected_fieldValue" ]]
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
        -d "{\"ref\":\"master\",\"inputs\":{\"title\": \"$title\", \"createdAt\": \"$createdAt\", \"updatedAt\": \"$updatedAt\", \"sender\": \"$sender\", \"itemId\": \"$itemId\"}}"
else
    echo "We are not interested in $fieldValue"
fi
