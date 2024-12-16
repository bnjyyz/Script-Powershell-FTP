# Demande des informations à l'utilisateur
$ftpServer = Read-Host "Entrez l'adresse IP du serveur FTP"
$ftpPort = Read-Host "Entrez le port FTP (appuyez sur Entrée pour utiliser le port par défaut 21)"
$ftpUser = Read-Host "Entrez le nom d'utilisateur FTP"
$ftpPassword = Read-Host "Entrez le mot de passe FTP" -AsSecureString
$remoteFile = Read-Host "Entrez le chemin complet du fichier à récupérer (ex : dossier/fichier.txt)"

# Informations pour l'email
$mailFrom = "test@gmail.com"  # Remplacez par l'email de l'expéditeur
$mailTo = "test@gmail.com"          # Email de l'administrateur
$smtpServer = "smtp.gmail.com"       # Serveur SMTP
$smtpPort = 587                        # Port SMTP
$smtpCredentialUser = "test@gmail.com"  # Nom d'utilisateur SMTP
$smtpCredentialPassword = "mdp"   # Mot de passe SMTP

# Variables pour l'état du transfert
$transferStatus = ""
$filesDownloaded = @()

# Utilisation du port par défaut si non renseigné
if ([string]::IsNullOrWhiteSpace($ftpPort)) {
    $ftpPort = 21
}

# Convertit le mot de passe sécurisé
$ftpPasswordPlain = [System.Net.NetworkCredential]::new("", $ftpPassword).Password

# Création de l'URI FTP
$ftpUri = "ftp://$ftpServer`:$ftpPort/$remoteFile"

# Récupération du nom de fichier depuis le chemin distant
$fileName = [System.IO.Path]::GetFileName($remoteFile)

# Chemin local pour sauvegarder le fichier
$localDirectory = "C:\temp"
$localPath = Join-Path -Path $localDirectory -ChildPath $fileName

# Création du dossier temporaire si nécessaire
if (-not (Test-Path -Path $localDirectory)) {
    Write-Host "Création du répertoire : $localDirectory"
    mkdir $localDirectory
}

# Téléchargement avec FtpWebRequest
try {
    Write-Host "Connexion au serveur FTP : $ftpUri"
    $request = [System.Net.FtpWebRequest]::Create($ftpUri)
    $request.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
    $request.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPasswordPlain)
    $request.UseBinary = $true
    $request.UsePassive = $true  # Active la connexion passive

    $response = $request.GetResponse()
    $responseStream = $response.GetResponseStream()
    $fileStream = [System.IO.File]::Create($localPath)

    $buffer = New-Object byte[] 1024
    $read = 0
    while (($read = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $fileStream.Write($buffer, 0, $read)
    }

    Write-Host "Fichier téléchargé avec succès vers $localPath" -ForegroundColor Green
    $transferStatus = "Succès"
    $filesDownloaded += $fileName  # Ajout du fichier téléchargé
} catch {
    Write-Host "Erreur : $($_.Exception.Message)" -ForegroundColor Red
    $transferStatus = "Échec"
} finally {
    if ($fileStream) { $fileStream.Close() }
    if ($responseStream) { $responseStream.Close() }
}

# Construction du message à envoyer
$mailSubject = "Rapport de transfert FTP"
$mailBody = @"
Bonjour,

Voici l'état du transfert FTP :

- Adresse FTP : $ftpUri
- État : $transferStatus
- Fichiers téléchargés : $(if ($filesDownloaded.Count -gt 0) { $filesDownloaded -join ", " } else { "Aucun fichier téléchargé." })

Cordialement,
Votre script FTP
"@

# Envoi de l'email
try {
    Send-MailMessage -From $mailFrom -To $mailTo -Subject $mailSubject -Body $mailBody -SmtpServer $smtpServer -Port $smtpPort -Credential (New-Object System.Management.Automation.PSCredential($smtpCredentialUser, (ConvertTo-SecureString $smtpCredentialPassword -AsPlainText -Force))) -UseSsl
    Write-Host "Email envoyé à l'administrateur : $mailTo" -ForegroundColor Green
} catch {
    Write-Host "Erreur lors de l'envoi de l'email : $($_.Exception.Message)" -ForegroundColor Red
}
