#!/bin/bash
#set -x

# ----------------------------------------------------------
# Source this script to get the send_email function
# Usage example:
# send_email -k "$SMTP2GO_KEY" -f "Second Son Consulting" \
#   -r "user1@example.com" -r "user2@example.com" \
#   -s "Test Message" -b "This is a test."
# ----------------------------------------------------------

function send_email() {
    local emailFromAddress="noreply@secondsonconsulting.com"
    local smtp2goSendingEndpoint="https://api.smtp2go.com/v3/email/send"

    # Initiate empty arrays and vars
    local emailRecipients=()
    local attachments=() # (reserved for later use)
    local smtp2goKey=""
    local emailFromName=""
    local emailSubject=""
    local emailBody=""
    local dryRun="curl"

    # Parse arguments
    while [ "$#" -ge 1 ]; do
        case "$1" in
            -k|--key)
                smtp2goKey="$2"
                shift 2
                ;;
            -r|--recipient)
                emailRecipients+=("$2"); shift 2 ;;
            -f|--fromname)
                emailFromName="$2"
                shift 2
                ;;
            -s|--subject)
                emailSubject="$2"
                shift 2
                ;;
            -b|--body)
                emailBody="$2"
                shift 2
                ;;
            -a|--attachment|--attachments)
                attachments+=("$2")
                shift 2
                ;;
            -t|--test|--testmode|--test-mode)
                dryRun="/bin/echo"
                shift
                ;;
            *)
                echo "Invalid option: $1"; return 1 ;;
        esac
    done

    # Verify required args
    local errorMessage=""
    [[ -z "$smtp2goKey" ]] && errorMessage+=" [-k | --key]"
    [[ -z "${emailRecipients[0]}" ]] && errorMessage+=" [-r | --recipient]"
    [[ -z "$emailFromName" ]] && errorMessage+=" [-f | --fromname]"
    [[ -z "$emailSubject" ]] && errorMessage+=" [-s | --subject]"
    [[ -z "$emailBody" ]] && errorMessage+=" [-b | --body]"

    if [[ -n "$errorMessage" ]]; then
        echo "ERROR: Missing argument(s):${errorMessage}"
        return 1
    fi

    # Summary
    echo "Preparing to send email:"
    echo "  API Key: ${smtp2goKey:0:3}...[REDACTED]"
    echo "  From: ${emailFromName} <${emailFromAddress}>"
    echo "  Subject: ${emailSubject}"
    echo "  Recipients:"
    for recipient in "${emailRecipients[@]}"; do
        echo "      $recipient"
    done
    if [ -n "${attachments[0]}" ]; then
        echo "  Attachments:"
        for attachment in "${attachments[@]}"; do
            echo "      $attachment"
        done
    fi    

    # Build JSON array for recipients
    local jsonRecipients
    jsonRecipients=$(printf '"%s",' "${emailRecipients[@]}")
    jsonRecipients="[${jsonRecipients%,}]"

    # Write initial JSON to a file (no large data in variables)
    local jsonFile
    jsonFile="$(mktemp /var/tmp/emailPayload.XXXXXX)"

    jq -n \
        --arg api_key "$smtp2goKey" \
        --arg from_name "$emailFromName" \
        --arg from_addr "$emailFromAddress" \
        --arg subject "$emailSubject" \
        --arg text_body "$emailBody" \
        --argjson to "$jsonRecipients" \
        '
        {
            api_key: $api_key,
            to: $to,
            sender: $from_addr,
            from: ($from_name + " <" + $from_addr + ">"),
            subject: $subject,
            text_body: $text_body,
            attachments: []
        }
        ' > "$jsonFile"


    # Append attachments directly into the JSON file
    # WE MUST AVOID using shell vars for attachment base64 values due to maximum argument limitations
    for attachment in "${attachments[@]}"; do
        mimeType=$(file --mime-type -b "$attachment")
        filename=$(basename "$attachment")

        tmp_b64=$(mktemp /var/tmp/attachmentBlob.XXXXXX)
        base64 -i "$attachment" > "$tmp_b64"

        jq --rawfile fileblob "$tmp_b64" \
           --arg filename "$filename" \
           --arg mimetype "$mimeType" \
           '
           .attachments += [{
               filename: $filename,
               mimetype: $mimetype,
               fileblob: $fileblob
           }]
           ' "$jsonFile" > "${jsonFile}.tmp" && mv "${jsonFile}.tmp" "$jsonFile"

        rm -f "$tmp_b64"
    done

    # Optional debug mode
    if [[ "$dryRun" != "curl" ]]; then
        echo "******* JSON DATA ******"
        jq . "$jsonFile"
        echo "******* END JSON DATA ******"
    fi

    echo "Sending email..."
    "$dryRun" --silent --location "$smtp2goSendingEndpoint" \
        --header "Content-Type: application/json" \
        --data-binary @"$jsonFile"

    [[ "$dryRun" == "curl" ]] && rm -f "$jsonFile"
}
