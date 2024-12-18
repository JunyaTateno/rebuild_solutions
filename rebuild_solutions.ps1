# Dictionaryでソリューションのリストを作成
$solutions = [System.Collections.Specialized.OrderedDictionary]::new()
$solutions.Add("sln1", "C:\Program Files (x86)\app\Source\sln1.sln")
$solutions.Add("sln2", "C:\Program Files (x86)\app\Source\sln2.sln")

# Visual Studio のパス
$vsPath = "C:\Program Files (x86)\Microsoft Visual Studio 10.0\Common7\IDE\devenv.com"

# コンポーネントの配置位置（y軸）を管理する変数
$y = 10

# GUIフォームの定義
Add-Type -AssemblyName System.Windows.Forms
$form = New-Object System.Windows.Forms.Form
$form.Text = "RebuildSolutions"
$form.Width = 500

# 説明ラベルの定義
$labels = @(
    "リビルドするソリューションを全て選択し、「リビルド開始」を押してください。"
)
foreach ($text in $labels) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $text
    $label.AutoSize = $true
    $label.Top = $y
    $label.Left = 10
    $form.Controls.Add($label)
    $y += $label.Height + 10
}

# リビルド設定用ドロップダウンリストの定義
$configurationLabel = New-Object System.Windows.Forms.Label
$configurationLabel.Text = "リビルド設定:"
$configurationLabel.AutoSize = $true
$configurationLabel.Top = $y + 10
$configurationLabel.Left = 20
$form.Controls.Add($configurationLabel)

$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Items.Add("Debug")
$comboBox.Items.Add("Release")
$comboBox.SelectedIndex = 0  # 初期値はDebug
$comboBox.Top = $configurationLabel.Top + ($configurationLabel.Height / 2) - ($comboBox.Height / 2)
$comboBox.Left = $configurationLabel.Left + $configurationLabel.Width + 10
$comboBox.Width = 80
$form.Controls.Add($comboBox)

# 次のコントロールの配置用にy軸を更新
$y += $comboBox.Height + 20

# チェックボックスとステータスラベルの定義
$checkboxes = @{ }
foreach ($solutionName in $solutions.Keys) {
    $solutionPath = $solutions[$solutionName]

    # チェックボックス
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = $solutionName
    $checkbox.Top = $y
    $checkbox.Left = 20

    # ステータスラベル
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Top = $y
    $statusLabel.Left = 200
    $statusLabel.AutoSize = $true

    # ファイルパスが存在しない場合の処理
    if (-Not (Test-Path -Path $solutionPath)) {
        $checkbox.Enabled = $false
        $statusLabel.Text = "ソリューションファイルが存在しません"
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
    }

    $form.Controls.Add($checkbox)
    $form.Controls.Add($statusLabel)
    $checkboxes[$solutionName] = $checkbox
    $y += 30
}

# 実行ボタンの定義
$button = New-Object System.Windows.Forms.Button
$button.Text = "リビルド開始"
$button.BackColor = [System.Drawing.Color]::LightBlue
$button.ForeColor = [System.Drawing.Color]::Black
$button.Top = $y + 10
$button.Left = 20
$button.Add_MouseEnter({
    $button.BackColor = [System.Drawing.Color]::DeepSkyBlue
})
$button.Add_MouseLeave({
    $button.BackColor = [System.Drawing.Color]::LightBlue
})
$form.Controls.Add($button)
$y += $button.Height + 30

# 進捗バーの定義
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Minimum = 0
$progressBar.Value = 0
$progressBar.Top = $y
$progressBar.Left = 20
$progressBar.Width = 350
$form.Controls.Add($progressBar)
$y += $progressBar.Height + 10

# 進捗ラベルの定義
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = ""
$statusLabel.AutoSize = $true
$statusLabel.Top = $y
$statusLabel.Left = 20
$form.Controls.Add($statusLabel)
$y += $statusLabel.Height + 20

# フォーム高さを設定
$form.ClientSize = New-Object System.Drawing.Size($form.Width, $y)

# 実行ボタンのクリックイベント
$button.Add_Click({
    $button.Enabled = $false
    $log = ""

    # 選択したリビルド構成を取得
    $selectedConfiguration = $comboBox.SelectedItem
    if (-not $selectedConfiguration) {
        [System.Windows.Forms.MessageBox]::Show("リビルド設定を選択してください。", "エラー")
        $button.Enabled = $true
        return
    }

    # チェックされたソリューションのDictinaryを作成
    $selectedSolutions = [System.Collections.Specialized.OrderedDictionary]::new()
    foreach ($solutionName in $solutions.Keys) {
        if ($checkboxes[$solutionName].Checked) {
            $selectedSolutions.Add($solutionName, $solutions[$solutionName])
        }
    }

    # なにもチェックされていない場合の処理
    if ($selectedSolutions.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("リビルド対象を選択してください。", "エラー")
        $button.Enabled = $true
        return
    }

    # 進捗バーの最大値、及び初期値を設定
    $progressBar.Maximum = $selectedSolutions.Count
    $progressBar.Value = 0

    # リビルド処理
    foreach ($solution in $selectedSolutions.GetEnumerator()) {
        $solutionName = $solution.Key
        $solutionPath = $solution.Value

        # 進捗バー、ステータスラベルを更新
        $statusLabel.Text = "リビルド中: $solutionName"
        $progressBar.Value += 1
        Write-Host "リビルド中: $solutionName..."

        try {
            # リビルドコマンドを実行し、終了コードを取得
            $process = Start-Process -FilePath "cmd.exe" `
                -ArgumentList "/c `"`"$vsPath`"` `"${solutionPath}`" /rebuild $selectedConfiguration`"" `
                -NoNewWindow -Wait -PassThru

            if ($process.ExitCode -eq 0) {
                $log += "成功: $solutionName`n"
                Start-Sleep -Seconds 1
            } else {
                $log += "失敗: $solutionName (終了コード: $($process.ExitCode))`n"
                break
            }
        } catch {
            $log += "失敗: $solutionName - エラー: $($_.Exception.Message)`n"
            break
        }
    }

    # 結果表示
    $statusLabel.Text = "リビルド完了！"
    [System.Windows.Forms.MessageBox]::Show($log, "リビルド結果")
    $form.Close()
})

$form.ShowDialog()
