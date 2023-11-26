function Write-Centered {
    param (
        [Parameter(Mandatory)]
        [string]$Text,
        [switch]$NoNewline,
        [AllowNull()]
        $BackgroundColor = $null,
        [AllowNull()]
        $ForegroundColor = $null
    )

    # Create hashtable of parameters, so we can splat them to Write-Host.
    $params = @{
        NoNewline       = $NoNewline
        BackgroundColor = $BackgroundColor
        ForegroundColor = $ForegroundColor
    }

    # Create a new hashtable excluding entries with null values.
    $filteredParams = @{}
    foreach ($key in $params.Keys) {
        $value = $params[$key]
        if ($null -ne $value) {
            $filteredParams[$key] = $value
        }
    }

    # Get console width
    $consoleWidth = $Host.UI.RawUI.WindowSize.Width

    # If the text is longer than the console width -2, split the Text into an array of multiple lines
    $textArray = @()
    # Check if the length of the text is greater than the console width minus 2
    if ($Text.Length -gt ($consoleWidth - 2)) {
        # Store the length of the text and the maximum line length
        $textLength = $Text.Length
        $lineLength = $consoleWidth - 2

        # Calculate the number of lines needed to display the text
        $lineCount = [math]::Ceiling($textLength / $lineLength)

        # Initialize variables for the start index and the length of the substring that will be truncated
        $startIndex = 0
        $truncatedSubstringLength = 0
        
        # Loop through each line
        for ($i = 0; $i -lt $lineCount; $i++) {
            # Calculate the end index for the substring
            $endIndex = [math]::Min((($i + 1) * $lineLength) - $truncatedSubstringLength, $textLength)

            # Extract the line from the text
            $line = $Text.Substring($startIndex, $endIndex - $startIndex)

            if ($i -lt $lineCount - 1) {
                # Find the last space in the line
                $lastSpaceIndex = $line.LastIndexOf(' ')
                # If a space was found, truncate the line at the last space
                if ($lastSpaceIndex -gt 0) {
                    # Calculate the length of the substring that will be truncated
                    $truncatedSubstringLength = $line.Length - $lastSpaceIndex
                    # Calculate the start index for the next line
                    $startIndex = $endIndex - $truncatedSubstringLength
                    $line = $line.Substring(0, $lastSpaceIndex)
                }
            }  
            
            # Add the line to the text array
            $textArray += $line.Trim()
        }
    }
    else {
        $textArray += $Text
    }

    # Iterate through each line in the array
    foreach ($line in $textArray) {
        # Calculate padding to center text
        $padding = [math]::Max(0, [math]::Floor((($consoleWidth - $line.Length) / 2)))

        # Calculate right padding
        $rightPadding = $consoleWidth - $line.Length - $padding

        # Write text to console with padding, using the filtered parameters.
        Write-Host ((' ' * $padding) + $line + (' ' * $rightPadding)) @filteredParams
    }
}

# Call the function
Write-Centered -Text 'The quick brown fox jumps over the lazy dog while the sun shines brightly over the beautiful green meadows.  Programming is a fascinating process that involves the use of languages like Python, Java, C++, and many others to create functional software.  Artificial intelligence and machine learning are transforming the way we interact with technology and understand data.' -ForegroundColor White -BackgroundColor Blue