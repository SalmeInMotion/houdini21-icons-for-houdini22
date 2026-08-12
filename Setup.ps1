[CmdletBinding()]
param(
    [switch]$DetectOnly,
    [ValidateSet('auto', 'en', 'es')]
    [string]$Language = 'auto'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'HoudiniIcons.Common.ps1')

$detected21 = @(Get-HoudiniInstallCandidates -ExpectedMajor 21)
$detected22 = @(Get-HoudiniInstallCandidates -ExpectedMajor 22)
$installedOverlays = @(Get-HoudiniIconModInstalledOverlays)

if ($DetectOnly) {
    [ordered]@{
        houdini21 = @($detected21 | Select-Object Version, Root)
        houdini22 = @($detected22 | Select-Object Version, Root)
        installedOverlays = @($installedOverlays | ForEach-Object {
            [ordered]@{
                dataRoot = $_.DataRoot
                sourceVersion = [string]$_.Manifest.source.version
                sourceRoot = [string]$_.Manifest.source.installRoot
                targetVersion = [string]$_.Manifest.target.version
                targetRoot = [string]$_.Manifest.target.installRoot
            }
        })
    } | ConvertTo-Json -Depth 6
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$useSpanish = $Language -eq 'es'
if ($Language -eq 'auto') {
    $useSpanish = [Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'es'
}

if ($useSpanish) {
    $text = @{
        Window = 'Houdini 21 Icons for Houdini 22'
        Intro = 'Selecciona tus instalaciones de Houdini. No se modificará ningún archivo dentro de Program Files.'
        H21 = 'Instalación de Houdini 21'
        H22 = 'Instalación de Houdini 22'
        Browse = 'Buscar...'
        Install = 'Instalar / Actualizar'
        Verify = 'Comprobar'
        Uninstall = 'Desinstalar'
        Close = 'Cerrar'
        Ready = 'Listo. Las instalaciones detectadas se han seleccionado automáticamente.'
        Working = 'Trabajando...'
        Invalid = 'Selecciona una instalación válida de Houdini {0}.'
        Valid = 'Houdini {0} detectado correctamente'
        Choose = 'Selecciona la carpeta principal de Houdini {0}'
        InstallDone = 'Instalación completada. Reinicia todas las ventanas de Houdini 22.'
        VerifyDone = 'La comprobación ha terminado correctamente.'
        UninstallDone = 'Desinstalación completada. Houdini 22 volverá a sus iconos originales.'
        ConfirmUninstall = '¿Quieres desinstalar los iconos clásicos de la build seleccionada de Houdini 22?'
        Confirmation = 'Confirmar desinstalación'
        Error = 'Error'
        Details = 'Detalles'
        Auto = 'Se detectaron {0} instalaciones de H21 y {1} instalaciones de H22.'
        BuildSafe = 'Cada overlay queda asociado a la build exacta de H22 seleccionada.'
    }
}
else {
    $text = @{
        Window = 'Houdini 21 Icons for Houdini 22'
        Intro = 'Select your Houdini installations. No files inside Program Files will be modified.'
        H21 = 'Houdini 21 installation'
        H22 = 'Houdini 22 installation'
        Browse = 'Browse...'
        Install = 'Install / Update'
        Verify = 'Verify'
        Uninstall = 'Uninstall'
        Close = 'Close'
        Ready = 'Ready. Detected installations were selected automatically.'
        Working = 'Working...'
        Invalid = 'Select a valid Houdini {0} installation.'
        Valid = 'Houdini {0} detected successfully'
        Choose = 'Select the Houdini {0} installation folder'
        InstallDone = 'Installation completed. Restart every Houdini 22 window.'
        VerifyDone = 'Verification completed successfully.'
        UninstallDone = 'Uninstall completed. Houdini 22 will use its original icons.'
        ConfirmUninstall = 'Uninstall the classic icons for the selected Houdini 22 build?'
        Confirmation = 'Confirm uninstall'
        Error = 'Error'
        Details = 'Details'
        Auto = 'Detected {0} H21 installation(s) and {1} H22 installation(s).'
        BuildSafe = 'Each overlay is restricted to the exact selected Houdini 22 build.'
    }
}

function Add-UniqueComboPath {
    param(
        [Parameter(Mandatory = $true)][System.Windows.Forms.ComboBox]$Combo,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    foreach ($item in $Combo.Items) {
        if ([string]$item -ieq $Path) { return }
    }
    [void]$Combo.Items.Add($Path)
}

function Quote-ProcessArgument {
    param([Parameter(Mandatory = $true)][string]$Value)
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Invoke-SetupCommand {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptName,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $powerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $commandArguments = New-Object System.Collections.Generic.List[string]
    foreach ($argument in @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot $ScriptName)) + $Arguments) {
        $commandArguments.Add((Quote-ProcessArgument -Value $argument))
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $powerShellExe
    $startInfo.Arguments = $commandArguments -join ' '
    $startInfo.WorkingDirectory = $PSScriptRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        Output = (($standardOutput.TrimEnd(), $standardError.TrimEnd()) | Where-Object { $_ }) -join [Environment]::NewLine
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = $text.Window
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(820, 530)
$form.MinimumSize = New-Object System.Drawing.Size(760, 500)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.BackColor = [System.Drawing.Color]::FromArgb(246, 247, 249)

$layout = New-Object System.Windows.Forms.TableLayoutPanel
$layout.Dock = 'Fill'
$layout.Padding = New-Object System.Windows.Forms.Padding(22, 18, 22, 18)
$layout.ColumnCount = 3
$layout.RowCount = 11
$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 165)))
$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 100)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 42)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 44)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 38)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 38)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 36)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 32)))
$form.Controls.Add($layout)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = $text.Window
$titleLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(35, 40, 47)
$titleLabel.Dock = 'Fill'
$titleLabel.TextAlign = 'MiddleLeft'
$layout.Controls.Add($titleLabel, 0, 0)
$layout.SetColumnSpan($titleLabel, 3)

$introLabel = New-Object System.Windows.Forms.Label
$introLabel.Text = $text.Intro + [Environment]::NewLine + $text.BuildSafe
$introLabel.ForeColor = [System.Drawing.Color]::FromArgb(75, 82, 92)
$introLabel.Dock = 'Fill'
$introLabel.TextAlign = 'MiddleLeft'
$layout.Controls.Add($introLabel, 0, 1)
$layout.SetColumnSpan($introLabel, 3)

$h21Label = New-Object System.Windows.Forms.Label
$h21Label.Text = $text.H21
$h21Label.Dock = 'Fill'
$h21Label.TextAlign = 'MiddleLeft'
$layout.Controls.Add($h21Label, 0, 2)

$h21Combo = New-Object System.Windows.Forms.ComboBox
$h21Combo.Dock = 'Fill'
$h21Combo.DropDownStyle = 'DropDown'
$h21Combo.AutoCompleteMode = 'SuggestAppend'
$h21Combo.AutoCompleteSource = 'ListItems'
$layout.Controls.Add($h21Combo, 1, 2)

$h21Browse = New-Object System.Windows.Forms.Button
$h21Browse.Text = $text.Browse
$h21Browse.Dock = 'Fill'
$layout.Controls.Add($h21Browse, 2, 2)

$h21Status = New-Object System.Windows.Forms.Label
$h21Status.Dock = 'Fill'
$h21Status.TextAlign = 'MiddleLeft'
$layout.Controls.Add($h21Status, 1, 3)
$layout.SetColumnSpan($h21Status, 2)

$h22Label = New-Object System.Windows.Forms.Label
$h22Label.Text = $text.H22
$h22Label.Dock = 'Fill'
$h22Label.TextAlign = 'MiddleLeft'
$layout.Controls.Add($h22Label, 0, 4)

$h22Combo = New-Object System.Windows.Forms.ComboBox
$h22Combo.Dock = 'Fill'
$h22Combo.DropDownStyle = 'DropDown'
$h22Combo.AutoCompleteMode = 'SuggestAppend'
$h22Combo.AutoCompleteSource = 'ListItems'
$layout.Controls.Add($h22Combo, 1, 4)

$h22Browse = New-Object System.Windows.Forms.Button
$h22Browse.Text = $text.Browse
$h22Browse.Dock = 'Fill'
$layout.Controls.Add($h22Browse, 2, 4)

$h22Status = New-Object System.Windows.Forms.Label
$h22Status.Dock = 'Fill'
$h22Status.TextAlign = 'MiddleLeft'
$layout.Controls.Add($h22Status, 1, 5)
$layout.SetColumnSpan($h22Status, 2)

$detectedLabel = New-Object System.Windows.Forms.Label
$detectedLabel.Text = $text.Auto -f $detected21.Count, $detected22.Count
$detectedLabel.ForeColor = [System.Drawing.Color]::FromArgb(80, 90, 105)
$detectedLabel.Dock = 'Fill'
$detectedLabel.TextAlign = 'MiddleLeft'
$layout.Controls.Add($detectedLabel, 0, 6)
$layout.SetColumnSpan($detectedLabel, 3)

$buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$buttonPanel.Dock = 'Fill'
$buttonPanel.FlowDirection = 'LeftToRight'
$buttonPanel.WrapContents = $false
$buttonPanel.Padding = New-Object System.Windows.Forms.Padding(0, 7, 0, 5)
$layout.Controls.Add($buttonPanel, 0, 7)
$layout.SetColumnSpan($buttonPanel, 3)

$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = $text.Install
$installButton.Size = New-Object System.Drawing.Size(155, 34)
$installButton.BackColor = [System.Drawing.Color]::FromArgb(44, 112, 196)
$installButton.ForeColor = [System.Drawing.Color]::White
$installButton.FlatStyle = 'Flat'
$installButton.FlatAppearance.BorderSize = 0
$buttonPanel.Controls.Add($installButton)

$verifyButton = New-Object System.Windows.Forms.Button
$verifyButton.Text = $text.Verify
$verifyButton.Size = New-Object System.Drawing.Size(120, 34)
$buttonPanel.Controls.Add($verifyButton)

$uninstallButton = New-Object System.Windows.Forms.Button
$uninstallButton.Text = $text.Uninstall
$uninstallButton.Size = New-Object System.Drawing.Size(120, 34)
$buttonPanel.Controls.Add($uninstallButton)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = $text.Close
$closeButton.Size = New-Object System.Drawing.Size(100, 34)
$buttonPanel.Controls.Add($closeButton)

$detailsLabel = New-Object System.Windows.Forms.Label
$detailsLabel.Text = $text.Details
$detailsLabel.Dock = 'Fill'
$detailsLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
$detailsLabel.TextAlign = 'MiddleLeft'
$layout.Controls.Add($detailsLabel, 0, 8)
$layout.SetColumnSpan($detailsLabel, 3)

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Dock = 'Fill'
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::White
$logBox.BorderStyle = 'FixedSingle'
$logBox.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$layout.Controls.Add($logBox, 0, 9)
$layout.SetColumnSpan($logBox, 3)

$mainStatus = New-Object System.Windows.Forms.Label
$mainStatus.Text = $text.Ready
$mainStatus.Dock = 'Fill'
$mainStatus.TextAlign = 'MiddleLeft'
$mainStatus.ForeColor = [System.Drawing.Color]::FromArgb(52, 105, 64)
$layout.Controls.Add($mainStatus, 0, 10)
$layout.SetColumnSpan($mainStatus, 3)

foreach ($install in $detected21) { Add-UniqueComboPath -Combo $h21Combo -Path $install.Root }
foreach ($install in $detected22) { Add-UniqueComboPath -Combo $h22Combo -Path $install.Root }

$preferred21 = if ($detected21.Count -gt 0) { $detected21[0].Root } else { '' }
$preferred22 = if ($detected22.Count -gt 0) { $detected22[0].Root } else { '' }
if ($installedOverlays.Count -gt 0) {
    $mostRecentOverlay = $installedOverlays | Sort-Object -Property { [datetime]$_.Manifest.installedAtUtc } -Descending | Select-Object -First 1
    if (Test-Path -LiteralPath ([string]$mostRecentOverlay.Manifest.source.installRoot) -PathType Container) {
        $installedSourceRoot = [string]$mostRecentOverlay.Manifest.source.installRoot
        Add-UniqueComboPath -Combo $h21Combo -Path $installedSourceRoot
        if ([string]::IsNullOrWhiteSpace($preferred21)) { $preferred21 = $installedSourceRoot }
    }
    if (Test-Path -LiteralPath ([string]$mostRecentOverlay.Manifest.target.installRoot) -PathType Container) {
        $installedTargetRoot = [string]$mostRecentOverlay.Manifest.target.installRoot
        Add-UniqueComboPath -Combo $h22Combo -Path $installedTargetRoot
        if ([string]::IsNullOrWhiteSpace($preferred22)) { $preferred22 = $installedTargetRoot }
    }
}
$h21Combo.Text = $preferred21
$h22Combo.Text = $preferred22

function Update-PathStatus {
    param(
        [Parameter(Mandatory = $true)][System.Windows.Forms.ComboBox]$Combo,
        [Parameter(Mandatory = $true)][System.Windows.Forms.Label]$StatusLabel,
        [Parameter(Mandatory = $true)][int]$Major
    )
    try {
        $install = Assert-HoudiniInstall -InstallRoot $Combo.Text -ExpectedMajor $Major
        $StatusLabel.Text = ([char]0x2713) + ' ' + ($text.Valid -f $install.Version)
        $StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(42, 120, 58)
        return $install
    }
    catch {
        $StatusLabel.Text = ($text.Invalid -f $Major)
        $StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(170, 55, 55)
        return $null
    }
}

function Select-HoudiniFolder {
    param(
        [Parameter(Mandatory = $true)][System.Windows.Forms.ComboBox]$Combo,
        [Parameter(Mandatory = $true)][int]$Major
    )
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $text.Choose -f $Major
    $dialog.ShowNewFolderButton = $false
    $initialDirectory = Get-HoudiniBrowseInitialDirectory -Path ([string]$Combo.Text)
    if ($null -ne $initialDirectory) {
        $dialog.SelectedPath = $initialDirectory
    }
    try {
        if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            $Combo.Text = $dialog.SelectedPath
        }
    }
    finally {
        $dialog.Dispose()
    }
}

function Show-SetupUiError {
    param([Parameter(Mandatory = $true)][System.Management.Automation.ErrorRecord]$ErrorRecord)

    $message = $ErrorRecord.Exception.Message
    $logBox.Text = $message
    $mainStatus.Text = $text.Error
    $mainStatus.ForeColor = [System.Drawing.Color]::FromArgb(170, 55, 55)
    [void][System.Windows.Forms.MessageBox]::Show($form, $message, $text.Error, 'OK', 'Error')
}

function Set-Busy {
    param([Parameter(Mandatory = $true)][bool]$Busy)
    foreach ($control in @($h21Combo, $h22Combo, $h21Browse, $h22Browse, $installButton, $verifyButton, $uninstallButton, $closeButton)) {
        $control.Enabled = -not $Busy
    }
    $form.UseWaitCursor = $Busy
    if ($Busy) {
        $mainStatus.Text = $text.Working
        $mainStatus.ForeColor = [System.Drawing.Color]::FromArgb(50, 85, 150)
    }
    [System.Windows.Forms.Application]::DoEvents()
}

function Complete-Action {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$SuccessMessage
    )
    if (-not [string]::IsNullOrWhiteSpace($Result.Output)) {
        $logBox.Text = $Result.Output
        $logBox.SelectionStart = $logBox.TextLength
        $logBox.ScrollToCaret()
    }
    if ($Result.ExitCode -eq 0) {
        $mainStatus.Text = $SuccessMessage
        $mainStatus.ForeColor = [System.Drawing.Color]::FromArgb(42, 120, 58)
    }
    else {
        $mainStatus.Text = $text.Error + ' (' + $Result.ExitCode + ')'
        $mainStatus.ForeColor = [System.Drawing.Color]::FromArgb(170, 55, 55)
        [void][System.Windows.Forms.MessageBox]::Show($form, $Result.Output, $text.Error, 'OK', 'Error')
    }
}

$h21Browse.Add_Click({
    try { Select-HoudiniFolder -Combo $h21Combo -Major 21 }
    catch { Show-SetupUiError -ErrorRecord $_ }
})
$h22Browse.Add_Click({
    try { Select-HoudiniFolder -Combo $h22Combo -Major 22 }
    catch { Show-SetupUiError -ErrorRecord $_ }
})
$h21Combo.Add_TextChanged({ [void](Update-PathStatus -Combo $h21Combo -StatusLabel $h21Status -Major 21) })
$h22Combo.Add_TextChanged({ [void](Update-PathStatus -Combo $h22Combo -StatusLabel $h22Status -Major 22) })
$closeButton.Add_Click({ $form.Close() })

$installButton.Add_Click({
    $h21 = Update-PathStatus -Combo $h21Combo -StatusLabel $h21Status -Major 21
    $h22 = Update-PathStatus -Combo $h22Combo -StatusLabel $h22Status -Major 22
    if ($null -eq $h21 -or $null -eq $h22) { return }
    $h21Combo.Text = $h21.Root
    $h22Combo.Text = $h22.Root
    Set-Busy -Busy $true
    try {
        $result = Invoke-SetupCommand -ScriptName 'Install.ps1' -Arguments @('-Houdini21', $h21.Root, '-Houdini22', $h22.Root)
        Complete-Action -Result $result -SuccessMessage $text.InstallDone
    }
    catch {
        Complete-Action -Result ([pscustomobject]@{ ExitCode = 1; Output = $_.Exception.Message }) -SuccessMessage $text.InstallDone
    }
    finally { Set-Busy -Busy $false }
})

$verifyButton.Add_Click({
    $h22 = Update-PathStatus -Combo $h22Combo -StatusLabel $h22Status -Major 22
    if ($null -eq $h22) { return }
    $h22Combo.Text = $h22.Root
    Set-Busy -Busy $true
    try {
        $result = Invoke-SetupCommand -ScriptName 'Status.ps1' -Arguments @('-Houdini22', $h22.Root, '-VerifyFiles')
        Complete-Action -Result $result -SuccessMessage $text.VerifyDone
    }
    catch {
        Complete-Action -Result ([pscustomobject]@{ ExitCode = 1; Output = $_.Exception.Message }) -SuccessMessage $text.VerifyDone
    }
    finally { Set-Busy -Busy $false }
})

$uninstallButton.Add_Click({
    $h22 = Update-PathStatus -Combo $h22Combo -StatusLabel $h22Status -Major 22
    if ($null -eq $h22) { return }
    if ([System.Windows.Forms.MessageBox]::Show($form, $text.ConfirmUninstall, $text.Confirmation, 'YesNo', 'Question') -ne 'Yes') { return }
    $h22Combo.Text = $h22.Root
    Set-Busy -Busy $true
    try {
        $result = Invoke-SetupCommand -ScriptName 'Uninstall.ps1' -Arguments @('-Houdini22', $h22.Root)
        Complete-Action -Result $result -SuccessMessage $text.UninstallDone
    }
    catch {
        Complete-Action -Result ([pscustomobject]@{ ExitCode = 1; Output = $_.Exception.Message }) -SuccessMessage $text.UninstallDone
    }
    finally { Set-Busy -Busy $false }
})

[void](Update-PathStatus -Combo $h21Combo -StatusLabel $h21Status -Major 21)
[void](Update-PathStatus -Combo $h22Combo -StatusLabel $h22Status -Major 22)
$logBox.Text = $text.Auto -f $detected21.Count, $detected22.Count
[void]$form.ShowDialog()
