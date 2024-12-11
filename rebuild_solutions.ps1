# 順序付き辞書でソリューションのリストを作成
$solutions = [System.Collections.Specialized.OrderedDictionary]::new()
$solutions.Add("sln1", "C:\Program Files (x86)\app\Source\sln1.sln")
$solutions.Add("sln2", "C:\Program Files (x86)\app\Source\sln2.sln")

# Visual Studio のパス
$vsPath = "C:\Program Files (x86)\Microsoft Visual Studio 10.0\Common7\IDE\devenv.com"

# コンポーネントの配置位置（y軸）を管理する変数
$y = 10

# GUIフォームの定義     ※高さは全要素定義後に決定する
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
    $y += $label.Height + 10  # 各ラベルの高さ + 余白を追加
}

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
$button.Top = $y + 10  # チェックボックス群の下に余白を設けて配置
$button.Left = 20
# マウスを重ねた時に背景色を変える処理
$button.Add_MouseEnter({
    $button.BackColor = [System.Drawing.Color]::DeepSkyBlue
})
$button.Add_MouseLeave({
    $button.BackColor = [System.Drawing.Color]::LightBlue
})
$form.Controls.Add($button)
$y += $button.Height + 30  # 実行ボタンの高さ + 余白

# 進捗バーの定義
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Minimum = 0
$progressBar.Value = 0
$progressBar.Top = $y
$progressBar.Left = 20
$progressBar.Width = 350
$form.Controls.Add($progressBar)
$y += $progressBar.Height + 10  # 進捗バーの高さ + 余白

# 進捗ラベルの定義
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = ""
$statusLabel.AutoSize = $true
$statusLabel.Top = $y
$statusLabel.Left = 20
$form.Controls.Add($statusLabel)
$y += $statusLabel.Height + 20  # 進捗ラベルの高さ + 余白

# GUIフォームのクライアント領域の高さを設定
$form.ClientSize = New-Object System.Drawing.Size($form.Width, $y)

# 実行ボタンのクリックイベント
$button.Add_Click({
    $button.Enabled = $false  # ボタンを無効化

    # チェックされたソリューションの配列を作成
    $selectedSolutions = @{}
    foreach ($solutionName in $solutions.Keys) {
        if ($checkboxes[$solutionName].Checked) {
            $selectedSolutions[$solutionName] = $solutions[$solutionName]
        }
    }    

    # なにもチェックされていない場合の処理
    if ($selectedSolutions.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("リビルド対象を選択してください。", "エラー",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        $button.Enabled = $true  # ボタンを再び有効化
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
                -ArgumentList "/c `"`"$vsPath`"` `"${solutionPath}`" /rebuild Debug`"" `
                -NoNewWindow -Wait -PassThru

            # 終了コードにより、成功/失敗を判定
            if ($process.ExitCode -eq 0) {
                $log += "成功: $solutionName`n"
            } else {
                $log += "失敗: $solutionName - Visual Studioリビルドエラー (終了コード: $($process.ExitCode))`n"
                $log += "　　 Visual Studioからリビルドし、エラー詳細を確認してください`n"
                break
            }
        } catch {
            $log += "失敗: $solutionName - エラー: $($_.Exception.Message)`n"
            break
        }
    }
    $statusLabel.Text = "リビルド完了！"
    [System.Windows.Forms.MessageBox]::Show($log, "リビルド結果")
    $form.Close()
})

$form.ShowDialog()
