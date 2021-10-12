Add-Type -AssemblyName System.Web

    # Function starts
    function Get-ParamsFiles {
        param (
          $argsQuoted
        )

        $fileStr = ""
        $params = [System.Collections.ArrayList]::new()

        $words = $argsQuoted.Split(',')
        foreach ($word in $words) {
        $word = $word.Trim();

        # If word lenght > 0 check for '-' at the beginning if found store in params array if not found add to the fileStr
        if ( $word.Length -gt 0 ) {
          if ( $word  -like '-*' ) {
            # Add to parameters array
            [void]$params.Add($word)
          } else {
            # Append to fileStr
            $fileStr = ( $fileStr , $word ) -join ","
          }
        }
        }
        # Remove first comma
        $fileStr = $fileStr -replace "^,", ""

        return $params, $fileStr
    }
    # Function ends

    $token = $args[0]
    $argsQuoted = $args[1]

    $decodedString = [System.Web.HttpUtility]::UrlDecode($argsQuoted)
    # Write-Host "Decoded argsQuoted: " $argsQuoted

    # Separate parameters and files within argsQuoted
    $returnValue = Get-ParamsFiles $argsQuoted
    $paramList = $returnValue[0]
    $fileStr = $returnValue[1]

    # Check for -y option if found call the end point
    $dashy = $false
    foreach ($param in $paramList) {
        # Important: '-*y' means find '-' followed by any number of letters then y
        if ( $param -like '-*y' ) {
            # Write-Host "Found -y: " $param
            $dashy = $true
        }
    }
    If ($dashy) {
    $client = $args[2]
    $clientcwd = $args[3]

	Write-Host "Going to purge files in Elastic Search..."

	$Header = @{
		"X-Auth-Token" = "$token"
	}
	$BodyJson = @{
		"clientcwd" = "$clientcwd"
		"client" = "$client"
		"argsQuoted" = "$fileStr"
	} | ConvertTo-Json
	$Parameters = @{
		Method		= "POST"
		Uri			= "http://p4search.mydomain.com:1601/api/v1/obliterate"
		Headers		= $Header
		ContentType	= "application/json"
		Body		= $BodyJson
	}
    	Invoke-RestMethod @Parameters
    } Else {
        Write-Host "-y not present. Not calling endpoint."
    }
