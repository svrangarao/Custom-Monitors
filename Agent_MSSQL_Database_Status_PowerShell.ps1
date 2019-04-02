#################################################################################### 
 
# Custom monitor POWERSHELL scripts will be provided with below input parameters from agent while invoking the 
# script: 
# Cscript custom_script.ps1 ?g/metricName::metricName1|metricName2 /metric::metric1|metric2 /warn::warn1|warn2 /critical::crit1|crit2 /alert::do_alert1|do_alert2 /params::?hargs_string1|args_string2?h?h 

############################################################################ 
# Use the below block of code in all the POWERSHELL custom monitor scripts to parse the parameters: 
############################################################################ 
#$ErrorActionPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

 $filepath = split-path -parent $MyInvocation.MyCommand.Definition
 $fileAccessPath = split-path -parent $filepath
	
###########################################################################################
Function SendErrAlertToAB					
{
	param([string]$ExceptionStr)
	
	$ExceptionStr = ((((((( $ExceptionStr.Trim()).Replace("&" , "")).Replace(">" , "")).Replace("<" , "")).Replace('"' ,"")).Replace("'" ,"")).Replace('-' ,""))
	
	$currTime = [System.DateTime]::Now
		$timeStamp = [string]$currTime.Year + "-" + [String]$currTime.Month + "-" + [String]$currTime.Day + " " + [string]$currTime.Hour + ":" + [string]$currTime.Minute + ":" + [string]$currTime.Second
		
	$SocketXML = ""
	$SocketXML = $SocketXML + "<cm><id>AlertOutput</id><AlertOutput>"
	$SocketXML = $SocketXML + "<ServiceName>"+ "MSSQL_DataBase_Status" +"</ServiceName>"
	$SocketXML = $SocketXML + "<NewState>"+ "Critical" +"</NewState>"
	$SocketXML = $SocketXML + "<OldState>"+ "Ok" +"</OldState>"
	$SocketXML = $SocketXML + "<Description>" + "Exception : $ExceptionStr" +"</Description>"
	$SocketXML = $SocketXML + "<AlertTimeStamp>" + $timeStamp + "</AlertTimeStamp>"
	$SocketXML = $SocketXML + "<AlertType>Maintenance</AlertType>"
	$SocketXML = $SocketXML + "<UuId>"+ "MSSQL_DataBase_Status" +"</UuId>"
	$SocketXML = $SocketXML + "<Subject>" + "MSSQL_DataBase_Status Monitor Connection Failed" +"</Subject>"
	$SocketXML = $SocketXML + "</AlertOutput></cm>"
	#write-host "Sending Exception alert to AB"
	#write-host $SocketXML
	if($fileAccessPath.contains("x86"))
	{
		& "C:\Program Files (x86)\Vistara\Agent\bin\AgentSockIPC.exe" $SocketXml
	}
	else
	{
		& "C:\Program Files\Vistara\Agent\bin\AgentSockIPC.exe" $SocketXml
	}
}
###########################################################################################
Function SaveNewState						
{
	param([string]$MetricNameState,[string]$InstanceState,[string]$Value)

	Try
    {   
		$prevstatefolder = $fileAccessPath+"\log\prevstate"
		If (Test-Path $prevstatefolder)
		{
		}
		
		Else
		{ 
			New-Item -ItemType directory -Path $prevstatefolder
		}
		
		 
		
		$ExePath = $fileAccessPath + "\log\prevstate\" + $MetricNameState + ".txt"
		
		
			
			If (Test-Path $ExePath)
		{
			$monexists = 0
			$newdatafile = $null
			$fileReader = Get-Content $ExePath
			foreach($data in $fileReader)
			{
				#$MonitorName1 = $data -split("--", 2) #trim(Split(data, "--", 2)(0))
				#$MonitorName = $MonitorName1[0]  #.Trim()
				##echo "monitor= $MonitorName"
				#if([string]::Compare($MonitorName,$MetricNameState +":"+ $InstanceState, $True))               
				if($data.StartsWith($MetricNameState +":"+ $InstanceState))
				{	
					$monexists = 1
					$newdatafile = $newdatafile + $MetricNameState +":"+ $InstanceState + "--" + $Value + "`r`n"
				}
				Else
				{	if($data -ne ""){
					$newdatafile = $newdatafile + $data + "`r`n" }
				}
			}
			If($monexists -eq 0)
			{
				$newdatafile = $newdatafile + $MetricNameState +":"+ $InstanceState + "--" + $Value
			}
			$ExePath = $fileAccessPath + "/log/prevstate/"+ $MetricNameState + "_temp.txt"
			$newdatafile | Out-File $ExePath
			
			$sourcefilename = $fileAccessPath + "/log/prevstate/" + $MetricNameState + "_temp.txt"
			$detstinationfilename = $fileAccessPath + "/log/prevstate/" + $MetricNameState + ".txt"
			#echo "deleting old"
			Remove-Item $detstinationfilename
			Rename-Item $sourcefilename $detstinationfilename
			
		}
		Else
		{
			#Out-File $ExePath
			$MetricNameState +":"+ $InstanceState + "--" + $Value  | Out-File $ExePath
		}
	}
	catch
	{
		$ErrorMessage = $_.Exception.Message	
		write-host "Exception :	"$ErrorMessage
		SendErrAlertToAB "$ErrorMessage"
		Exit
	}
}

######################################################################################
# How to save old state: Use the below code to save old state 
#######################################################################################

Function CheckOldState						
{
	param([string]$MetricNameState,[string]$InstanceState)

	Try
	{
		$ExePath = $fileAccessPath + "\log\prevstate\" + $MetricNameState + ".txt"
		If (Test-Path $ExePath)
		{
			$oldstate = "Ok"
			$fileReader = Get-Content $ExePath             
			foreach($data in $fileReader)
			{
				if($data.StartsWith($MetricNameState +":"+ $InstanceState))
				{
					$oldstate = $data.Substring($data.IndexOf("--") + 2);
				}
			}
			$CheckOldState = $oldstate
		}
		else
		{
			$CheckOldState = "Ok"
		}

		return $CheckOldState
	}
	catch
	{
		$ErrorMessage = $_.Exception.Message	
		write-host "Exception :	"$ErrorMessage
		SendErrAlertToAB "$ErrorMessage"
		Exit
	}

}
#################################################################
#Check Heal state function
#################################################################
Function CheckHealState						
{
	param([string]$MetricNameState)
	
	Try
	{
		$ExePath = $fileAccessPath + "\log\prevstate\" + $MetricNameState + ".txt"
		$HealStatus = @()
		If (Test-Path $ExePath)
		{
			$fileReader = Get-Content $ExePath    
			foreach($data in $fileReader)
			{
				if($data.StartsWith($MetricNameState +":"))
				{
					$TABLE = New-Object system.Object
					$Str = $data.Substring($data.IndexOf(":")+1);
					#write-host "linessssssssssssssssss : "$Str
					$Strs = $Str.split("--",2)
					#write-host "strs array : "$Strs
					[String]$InstanceName = $Strs[0]
					[String]$InstanceStatus = $data.Substring($data.IndexOf("--")+2);
					#write-host "instance name : "$InstanceName
					#write-host "instance state : "$InstanceStatus
					$myHashtable = New-Object PSCustomObject
					$myHashtable | Add-Member -type NoteProperty -name InstanceName -Value $InstanceName
					$myHashtable | Add-Member -type NoteProperty -name InstanceStatus -Value $InstanceStatus
					#write-host "created object : "$myHashtable
					#write-host "created array type : "$HealStatus.gettype()
					$HealStatus += $myHashtable
				}
			}
		}
		else
		{
			write-host "file not found..."
		}
		return $HealStatus
	}
	catch
	{
		$ErrorMessage = $_.Exception.Message	
		write-host "Exception :	"$ErrorMessage
		SendErrAlertToAB "$ErrorMessage"
		Exit
	}
}


################################################################## 
# How to send alert: Use the below code to send alert 
################################################################## 



Function SendAlertToAB					
{
	param([string]$MetricInstance,[string]$Instance,[string]$OldState,[string]$NewState,[int]$Value,[String]$AlertDescription,[String]$AlertSubject)
	$currTime = [System.DateTime]::Now
		$timeStamp = [string]$currTime.Year + "-" + [String]$currTime.Month + "-" + [String]$currTime.Day + " " + [string]$currTime.Hour + ":" + [string]$currTime.Minute + ":" + [string]$currTime.Second
		
	$SocketXML = ""
	$SocketXML = $SocketXML + "<cm><id>AlertOutput</id><AlertOutput>"
	$SocketXML = $SocketXML + "<ServiceName>"+ $MetricInstance+"</ServiceName>"
	$SocketXML = $SocketXML + "<NewState>"+ $NewState+"</NewState>"
	$SocketXML = $SocketXML + "<OldState>"+ $OldState+"</OldState>"
	$SocketXML = $SocketXML + "<Description>" + $AlertDescription +"</Description>"
	$SocketXML = $SocketXML + "<AlertTimeStamp>" + $timeStamp + "</AlertTimeStamp>"
	$SocketXML = $SocketXML + "<AlertType>Monitoring</AlertType>"
	If ($Instance -ne "")
	{
		$SocketXML = $SocketXML + "<UuId>"+ $MetricInstance + "_" +$Instance+"</UuId>"
	}
	Else
	{
		$SocketXML = $SocketXML + "<UuId>"+ $MetricInstance +"</UuId>"
	}
	$SocketXML = $SocketXML + "<Subject>" + $AlertSubject +"</Subject>"
	$SocketXML = $SocketXML + "</AlertOutput></cm>"

	if($fileAccessPath.contains("x86"))
        {
		& "C:\Program Files (x86)\Vistara\Agent\bin\AgentSockIPC.exe" $SocketXml
	}
	else
	{
		& "C:\Program Files\Vistara\Agent\bin\AgentSockIPC.exe" $SocketXml
	}
	
}
	
#######################################################################################
# How to retrieve monitor values : Use the below code to retrieve monitor values  
#######################################################################################

Function ProcessMonitor					
{
Param([Int]$Index)
	Try
	{
		$metrictemp = $MetricName[$index]

		$perfdataOutput = "<Monitor name="+ $metrictemp + " output="
		#write-host $params[$Index]
		[String]$inputParams = $params[$Index]
		$inputParams = $inputParams.replace("'","")
		$inputParams = $inputParams.replace("[0]","")
		#write-host $inputParams
		$inputs = $inputParams.split(" ")
		[String]$dataSource = $inputs[0]
		[String]$userName = $inputs[1]
		[String]$passWord = $inputs[2]
		#write-host "dataSource : "$dataSource
		#write-host "userName : "$userName
		#write-host "passWord : "$passWord
		########################################################################################
		#[string]$connstr="Provider=SQLOLEDB.1;Integrated Security=SSPI;Persist Security Info=False;Data Source=sqlclusterdemo;Initial Catalog=Master;User ID=sa;Password=Pass@123"
		
		[string]$connstr="Provider=SQLOLEDB.1;Integrated Security=SSPI;Persist Security Info=False;Data Source=$dataSource;Initial Catalog=Master;User ID=$userName;Password=$passWord"
		
			
		$readconn = New-Object System.Data.OleDb.OleDbConnection
		$readcmd = New-Object system.Data.OleDb.OleDbCommand
		
		#write-host "connection string : "$connstr
		$readconn.connectionstring = $connstr
		$readconn.open()
		#write-host "connection opened...."
		$readcmd.connection=$readconn
		$readcmd.commandtext = "select name as database_name,state_desc, state from sys.databases"
		
		#write-host "read command : "$readcmd
		$reader = $readcmd.executereader()
		#write-host "reader status : "$reader.Fieldcount
		[String]$offlineDbList = ""
		$global:StatusCheck = $TRUE
		#####################################
		#$databaseNames = @{}
		#####################################
		if($($reader.HasRows))
		{
			#write-host "###########################Fetching Data from Database######################"
			do
			{
				#write-host "reader statusssss : "
				while ($reader.read() -eq "True")
				{
					#write-host "########################"
					[String]$dbName = $reader.Item("database_name")
					#write-host "Database Name : "$dbName
					[String]$MetricInstanceName = $dbName
					
					[String]$stateDesc =$reader.Item("state_desc")
					#write-host "state_desc : "$stateDesc
					
					[String]$state =$reader.Item("state")
					#write-host "State : "$state
					###########adding data to dict##################
					#$databaseNames.Add("$dbName", "$stateDesc")
					################################################
					#write-host "if condition : "$([String]$stateDesc.contains("ONLINE"))
					#if(!$([String]$stateDesc.contains("ONLINE")))
					if([Int]$state -ne 0)
					{
						$NewState = "Critical"
						$Subject = "Database [$dbName] Status : $stateDesc"
						$Description = "MSSQL_DataBase_Status : `nDatabase_Name - "+$dbName+"`nstate_desc - "+$stateDesc+"`nstate - "+$state
						$MetricValue = 1
					}
					else
					{
						$NewState = "Ok"
						$Subject = "Database [$dbName] Status : $stateDesc"
						$Description = "MSSQL_DataBase_Status : `nDatabase_Name - "+$dbName+"`nstate_desc - "+$stateDesc+"`nstate - "+$state
						$MetricValue = 0
					}
					
					If ( [string]$Alert_Flag[$index] -eq 1 )
					{
						$MetricNametemp=[string]$MetricName[$index]
						$OldState = CheckOldState "$MetricNametemp" "$MetricInstanceName"

						If ( $OldState -ne $NewState )
						{
							#Send Alert
							$Metrictemp = $Metric[$index] 
							SendAlertToAB "$Metrictemp" "$MetricInstanceName" "$OldState" "$NewState" "$MetricValue" "$Description" "$Subject"
							$check = $?
							if ( $check )
							{
								#Save New State
								$metrictemp = $MetricName[$index]
								SaveNewState "$metrictemp" "$MetricInstanceName" "$NewState"
							}							
						}
					}
					$perfdataOutput = $perfdataOutput + $MetricInstanceName + "=" + $MetricValue + "," 
					#write-host "pdata :"$perfdataOutput
				}
			}While ($reader.NextResult())

			#$perfdataOutput = $perfdataOutput + [string]$Metric[$index] + "=" + $MetricValue + "," 
		}
		<#
		if($databaseNames)
		{
			#write-host "#############Rows not found..........sending healing alerts...."
			$MetricNametemp=[string]$MetricName[$index]
			$retStatusDict = CheckHealState "$MetricNametemp"
			#write-host "return dict status: "$retStatusDict
			foreach($retStatus in $retStatusDict)
			{
				$MetricInstanceName = [String]$retStatus.InstanceName
				
				if (!($databaseNames.ContainsKey("$MetricInstanceName")))
				{
					#$MetricInstanceName = "Group_Listener_State"
					$OldState = [String]$retStatus.InstanceStatus
					$MetricValue = 0
					$NewState = "Ok"
					$Subject = "DataBase [$MetricInstanceName] Status - Ok"
					$Description = $Subject
					If ( [string]$Alert_Flag[$index] -eq 1 )
					{
						$MetricNametemp=[string]$MetricName[$index]
						#write-host "oldstate : "$OldState
						#write-host "newstate : "$NewState
						If ( $OldState -ne $NewState )
						{
							#Send Alert
							#write-host "sending alertttttttttttttttttt"
							$Metrictemp = $Metric[$index] 
							SendAlertToAB "$Metrictemp" "$MetricInstanceName" "$OldState" "$NewState" "$MetricValue" "$Description" "$Subject"
							$check = $?
							if ( $check )
							{
								#Save New State
			
								$metrictemp = $MetricName[$index]
								SaveNewState "$metrictemp" "$MetricInstanceName" "$NewState"
							}							
						}
					}
					$perfdataOutput = $perfdataOutput + $MetricInstanceName + "=" + $MetricValue + "," 
				}
			}
		
		}	
		#>
		$reader.close()
		if([String]$MetricInstanceName -eq "")
		{
			#$Metrictemp = $Metric[$index] 
			$MetricInstanceName = "mssql.database.status"
			$MetricValue = 0
			$perfdataOutput = $perfdataOutput + $MetricInstanceName + "=" + $MetricValue + "," 
		}
		$size = $perfdataOutput.length      #to remove last ","
		$perfdataOutput = $perfdataOutput.substring(0,$size-1)
		$perfdataOutput = $perfdataOutput + "/>"

		################################################################## 
		# How to send performance data: The console output should be as shown below: 
		################################################################## 


		write-host $perfdataOutput

		########################################################################################
	}
	catch
	{
		$ErrorMessage = $_.Exception.Message	
		write-host "Exception :	"$ErrorMessage
		SendErrAlertToAB "$ErrorMessage"
		##############################################
		#$Metrictemp = $Metric[$index] 
		$MetricInstanceName = "mssql.database.status"
		$MetricValue = 1
		$perfdataOutput = $perfdataOutput + $MetricInstanceName + "=" + $MetricValue + "," 

		$size = $perfdataOutput.length      #to remove last ","
		$perfdataOutput = $perfdataOutput.substring(0,$size-1)
		$perfdataOutput = $perfdataOutput + "/>"

		################################################################## 
		# How to send performance data: The console output should be as shown below: 
		################################################################## 
		write-host $perfdataOutput
	}
}


########################################################################
function SQLDataBaseStatus
{
	write-host "<DataValues>"
	for($i=0 ;$i -lt $MetricName.length ; $i++)
	{
		ProcessMonitor "$i"
	}
	write-host "</DataValues>"
}
#########################################################################

function GetArgs()
{
#param([String]$args)


#write-host "arguments are:" $args

	if($args.count -gt 0)
	{
	   for($i=0 ;$i -le $args.count-1 ;$i++)
		{
			$strArgs = $strArgs + [string]($args[$i])
		       
		}
	}
		
	if($strArgs.Contains("/metricName::") -ne 0)
	{
		$MetricNameTokens1 = $strArgs -split "/metricName::", 2
                $MetricNameTokens= $MetricNameTokens1[1].Trim() 

		if($MetricNameTokens.Contains("/") -ne 0)
		 {
			$MetricNameTokens1 = $MetricNameTokens -split "/", 2
              
			$MetricNameTokens = $MetricNameTokens1[0].Trim()
             
			
			#write-host "metricName " + $MetricNameTokens
	      
		 }
	}
	
	if($strArgs.Contains("/metric::") -ne 0)
	{

            $MetricTokens1 = $strArgs -split "/metric::", 2
            
	    $MetricTokens = $MetricTokens1[1].Trim()
            
	    if($MetricTokens.Contains("/") -ne 0)
	    {
	    
		     $MetricTokens1 = $MetricTokens -split "/", 2
		     
		     $MetricTokens = $MetricTokens1[0].Trim()
		    
		     #write-host "Metric is " + $MetricTokens

	    }

         }

         if($strArgs.Contains("/warn::") -ne 0)
	 {
		   $Warning_ThresTokens1 = $strArgs -split "warn::", 2
		   
		   $Warning_ThresTokens = $Warning_ThresTokens1[1].Trim()
         
		   if($Warning_ThresTokens.Contains("/") -ne 0)
		   {
			   $Warning_ThresTokens1 = $Warning_ThresTokens  -split "/", 2
			  
			   $Warning_ThresTokens =  $Warning_ThresTokens1[0].Trim()
			     #write-host "warn is " + $Warning_ThresTokens

		   }

          }

          if($strArgs.Contains("/critical::") -ne 0)
	  {
		  $Critical_ThresTokens1 = $strArgs -split "/critical::", 2
		  
		  $Critical_ThresTokens = $Critical_ThresTokens1[1].Trim()
		  
		  if($Critical_ThresTokens.Contains("/") -ne 0)
		  {
	  
			$Critical_ThresTokens1 = $Critical_ThresTokens -split "/", 2

			$Critical_ThresTokens = $Critical_ThresTokens1[0].Trim()
           
			#write-host "critical is " + $Critical_ThresTokens
		  }
	  }

	
          if($strArgs.Contains("/alert::") -ne 0)
	  {

		   $Alert_FlagTokens1 =  $strArgs -split "/alert::", 2
		  
		   $Alert_FlagTokens = $Alert_FlagTokens1[1].Trim()
		   
		   if($Alert_FlagTokens.Contains("/") -ne 0)
		   {
			    $Alert_FlagTokens1= $Alert_FlagTokens -split "/", 2
			    
			    $Alert_FlagTokens=  $Alert_FlagTokens1[0].Trim()
		            #write-host "Alert_FlagTokens " + $Alert_FlagTokens
		   }
	    
	    }

            if($strArgs.Contains("/params::") -ne 0)
	    {
	      
		$ParamsTokens1 = $strArgs -split "/params::", 2
		$ParamsTokens = $ParamsTokens1[1].Trim()
		      
		if($ParamsTokens.Contains("/") -ne 0)
		{
			$ParamsTokens1 = $ParamsTokens -split "/", 2
			$ParamsTokens = $ParamsTokens1[0].Trim()
			#write-host "params are " + $ParamsTokens
		 
		}

	      
	    }
	$MetricName = @()
	$Metric = @()
	$Warning_Thres = @()
        $Critical_Thres = @()
        $Alert_Flag = @()
        $Params = @() 

	$MetricName= $MetricNameTokens.split("|")
		
	$Metric=$MetricTokens.split("|")

	$Warning_Thres=$Warning_ThresTokens.split("|")
	
	
	$Critical_Thres=$Critical_ThresTokens.split("|")

	
	$Alert_Flag=$Alert_FlagTokens.split("|")
        
	$Params= $ParamsTokens.split("|")
	#write-host "###############################"$Params
        SQLDataBaseStatus

}
#write-host "calling arg funciton" $args[0]
#GetArgs "$args[0]"

####################################################################################################

Try
{
	$psfiledir = split-path -parent $MyInvocation.MyCommand.Definition
	if ($env:Processor_Architecture -eq 'x86')
	{
		$varbyte=c:\windows\sysnative\windowspowershell\v1.0\powershell.exe {[intptr]::size}
		if ($varbyte -eq 8)
		{
		#write-host "64-bit machine"
		c:\windows\sysnative\windowspowershell\v1.0\powershell.exe {set-executionpolicy "remotesigned"}
		c:\windows\sysnative\windowspowershell\v1.0\powershell.exe -command "&'$psfiledir\MSSQL_DataBase_Status1.ps1'" "'$args[0]'"
		}
		else
		{
			#write-host "32-bit machine"
			GetArgs "'$args[0]'"
		}
	}
	else
	{
		GetArgs "'$args[0]'"
	}
}
catch
{
	$ErrorMessage = $_.Exception.Message	
	write-host "Exception :	"$ErrorMessage
	SendErrAlertToAB "$ErrorMessage"
	Exit
}
