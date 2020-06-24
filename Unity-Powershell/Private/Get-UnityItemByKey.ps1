<#
    .SYNOPSIS
#>

Function Get-UnityItemByKey {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True,HelpMessage = 'EMC Unity Session')]
        $session,
        [Parameter(Mandatory = $True,HelpMessage = 'URI')]
        [String]$URI,
        [Parameter(Mandatory = $True,HelpMessage = 'Typename')]
        [String]$Typename,
        [Parameter(Mandatory = $True,HelpMessage = 'Key')]
        [String]$Key,
        [Parameter(Mandatory = $False,HelpMessage = 'Value')]
        [String[]]$Value,
        [parameter(Mandatory = $False, HelpMessage = 'Ressource Filter')]
        [string]$Filter
    )

    Begin {
        Write-Debug -Message "[$($MyInvocation.MyCommand)] Executing function"
    }

    Process {

      If ($Session.TestConnection()) {

        #Building the URL from Object Type.
        If ($Filter) {
            $URL = Get-URLFromObjectType -Session $Session -URI $URI -TypeName $TypeName -Compact -Filter $Filter
        } else {
            $URL = Get-URLFromObjectType -Session $Session -URI $URI -TypeName $TypeName -Compact
        }
        
        Write-Debug -Message "[$($MyInvocation.MyCommand)] URL: $URL"

        #Sending the request
        $request = Send-UnityRequest -uri $URL -Session $Session -Method 'GET'

        #Formating the result. Converting it from JSON to a Powershell object
        $Results = @()
        $Results += ($request.content | ConvertFrom-Json).entries.content
        
        Write-Debug -Message "Results Count: $($Results.Count)"
        if (($Results.Count % 2000) -eq 0)
        {
            Write-Debug -Message "More than 2000 results, querying additional records"
            $page = 2
            DO
            {
                $pageURI = $URL + "&page=" + $page
                Write-Debug -Message "Page URI: $($PageURI)"
                
                #Sending the request
                $request = Send-UnityRequest -uri $pageURI -Session $Session -Method 'GET'
                
                #Formating the result. Converting it from JSON to a Powershell object
                $RequestResults = ($request.content | ConvertFrom-Json).entries.content
                
                #Check if request results are empty before adding to results and break loop if no results are returned
                if ($RequestResults)
	            {
	                $Results += $RequestResults
	            } else
                {
                    Write-Debug -Message "No results from this call, breaking loop"
                    break
                }
                
                Write-Debug -Message "Results Count: $($Results.Count)"
                
                $page++
            } while (($Results.Count % 2000) -eq 0)
        }

        #Building the result collection (Add ressource type)
        If ($Results) {

            $ResultsFiltered = @()

            If (-not $Value) {
                $Value = '*'
            }
          
            # Results filtering
            $ResultsFiltered += Find-FromFilter -Parameter $Key -Filter $Value -Data $Results

            If ($ResultsFiltered) {

                Foreach ($Result in $ResultsFiltered) {

                    # Instantiate and output object if not null
                    New-UnityObject -TypeName $TypeName -Data $Result

                } # End Foreach ($Result in $ResultsFiltered)
            } # End If ($ResultsFiltered) 
        } else {
            Write-Error -Message "Object(s) not found" -Category ObjectNotFound
        } # End If ($Results)
    } # End If ($Sess.TestConnection())

  }
    
}
