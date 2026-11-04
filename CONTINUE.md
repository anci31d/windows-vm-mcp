# Продолжение установки Windows VM

Загрузки остановлены по запросу. **Windows и VirtIO ISO неполные. VM ещё не создана, не установлена и не проверена.** До завершения загрузок `bin/winvm` откажется запускаться.

1. Откройте https://www.microsoft.com/en-us/software-download/windows11, в разделе ISO выберите Windows 11 x64 и English International. На момент подготовки была выбрана сборка **26300.9457**, размер **9061271552 байт**, SHA-256 `7e3f373bd3c2321b5d5125dfcf718dfbf1a0abc50a267118669951890df98a5d`. Проверьте текущие сборку и хеш на странице Microsoft в разделе Verify your download.
2. Если сайт по-прежнему предлагает эту сборку, получите новую ссылку на загрузку (действует 24 часа) и продолжите скачивание начального фрагмента. Скопируйте URL в переменную `WINDOWS_ISO_URL` и выполните из workspace:

   ```bash
   curl -fL -C - -o windows-11-English-International/windows-11.iso "$WINDOWS_ISO_URL"
   printf '%s  %s\n' 7e3f373bd3c2321b5d5125dfcf718dfbf1a0abc50a267118669951890df98a5d windows-11-English-International/windows-11.iso | sha256sum -c -
   ```

   Убедитесь, что сервер поддерживает докачку; при ошибке или несовпадении хеша скачайте ISO заново. Если Microsoft предлагает другую сборку, скачайте её заново, проверьте её хеш по странице Microsoft и обновите проверку размера в `bin/winvm`. Файлы `assistant-work/download-fragments/part-*` — сохранённые фрагменты параллельной загрузки, в указанных командах они не используются.
3. Докачайте VirtIO, затем убедитесь в целостности образа по опубликованной поставщиком контрольной сумме, если она доступна:

   ```bash
   curl -fL -C - -o windows-11-English-International/virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.302-1/virtio-win-0.1.302.iso
   file windows-11-English-International/virtio-win.iso
   ```

   Проверка `file` определяет формат, но не подтверждает целостность. Если сервер не поддерживает докачку, загрузите файл заново.
4. Просмотрите настройки и условия установки в `README.md` и unattended XML. Запустите `bin/winvm gui`; дождитесь установки и входа. Возможны ручные действия в установщике. Для KVM и GUI может требоваться запуск вне песочницы агента.
5. После установки проверьте `bin/win-agent ping` и `bin/win-agent run 'C:\Windows\System32\cmd.exe' /c ver`. Положите x64dbg и `install-tools.ps1` на подключённый диск `tools.iso`. В PowerShell внутри VM найдите CD с `install-tools.ps1` и выполните его: он распакует x64dbg в `C:\CTF-Tools`, а Sysinternals скачает с Microsoft только после явного подтверждения.
6. Проверьте GUI, запуск/копирование файлов через агент и корректное выключение; после этого сохраните резервную копию выключенной VM вместе с EFI/TPM-состоянием. См. `README.md`.
