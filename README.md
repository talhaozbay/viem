# VMIsolator — VirtualBox VM İzolasyon Aracı

Zararlı yazılım analizi ve pentest laboratuvarı için, seçilen bir VirtualBox VM'ini
ana makineden mümkün olan en yüksek düzeyde izole eder. Tüm host↔guest veri
kanallarını kapatır, saldırı yüzeyini daraltır ve ağ bağlantısını sizin
seçtiğiniz izolasyon modeline göre yapılandırır.

Test edildiği ortam: **VirtualBox 7.2.6**, Windows 11, Windows PowerShell 5.1.

---

## Nasıl çalıştırılır

Kurulum yok. Depoyu indirin ve **`VMIsolator.cmd` dosyasına çift tıklayın.**

> `.ps1` dosyasına çift tıklamayın — Windows onu Not Defteri'nde açar. Bu bir hata
> değil, kasıtlı bir güvenlik önlemidir. `.cmd` başlatıcı bunu ve aşağıdaki iki
> engeli sizin için çözer.

Terminalden çalıştırmayı tercih ederseniz:

```powershell
# Etkileşimli mod — VM'leri listeler, sayıyla seçmenizi ister
.\VMIsolator.cmd

# Önce ne yapacağını görmek için (hiçbir şey değiştirmez)
.\VMIsolator.cmd -DryRun

# PowerShell'i doğrudan çağırmak isterseniz
powershell -NoProfile -ExecutionPolicy Bypass -File .\VMIsolator.ps1 -DryRun
```

### Başlatıcının çözdüğü engeller

| Engel | Ne olur | Başlatıcı ne yapar |
|-------|---------|--------------------|
| **Dosya ilişkilendirmesi** | `.ps1`'e çift tıklayınca Not Defteri açılır | `.cmd` çift tıklanabilir ve PowerShell'i kendisi çağırır |
| **Execution Policy** | `running scripts is disabled on this system` hatası | `-ExecutionPolicy Bypass` — **yalnızca o süreç için**, sistem ayarınız değişmez |
| **Mark of the Web** | GitHub'dan inen ZIP'teki dosyalar "internetten geldi" diye engellenir | Açılışta `Unblock-File` ile sessizce temizler |

Yönetici hakkı gerekmez — `VBoxManage` ile yapılan tüm işlemler normal kullanıcı
yetkisiyle çalışır.

**Gereksinimler:** Windows PowerShell 5.1 (Windows 10/11'de hazır gelir) ve VirtualBox.

Akış:

1. Tüm VM'leri durumu ve mevcut ağ yapılandırmasıyla listeler → sayıyla seçersiniz
2. VM açıksa kapatmayı teklif eder (`modifyvm` yalnızca kapalı VM'de çalışır)
3. "İnternete bağlansın mı?" diye sorar
4. Cevaba göre ağ modunu ve gerekiyorsa hangi kablosuz adaptörü sorar
5. Tüm izolasyon ayarlarını uygular
6. Uygulanan her ayarı VM konfigürasyonundan geri okuyarak **doğrular**
7. Analiz öncesi "clean" snapshot almayı teklif eder

---

## Ağ modları — izolasyon sırasına göre

| # | Mod | İzolasyon | Açıklama |
|---|-----|-----------|----------|
| 1 | **`off`** | ★★★★★ | VM içinde hiç ağ kartı yok. Sıfır ağ teması. |
| 2 | **`usbwifi`** | ★★★★☆ | Harici kablosuz adaptör USB passthrough ile doğrudan VM'e verilir. Sanal NIC yok. |
| 3 | **`intnet`** | ★★★★☆ | Yalnızca dahili ağ. VM'ler birbirini görür; host ve internet görünmez. |
| 4 | **`bridged`** | ★★☆☆☆ | Host adaptörü üzerinden köprüleme. Kolay ama host sürücü yığını trafik yolunda. |

### Neden `usbwifi` > `bridged`?

**Bridged** modda paketler host'un ağ sürücüsünden ve VirtualBox'ın köprüleme
NDIS filtresinden geçer — yani host çekirdeği zararlı trafiği **işler**. Ayrıca VM,
adaptörün bağlı olduğu ağa L2 seviyesinde katılır; adaptör host'unuzla aynı
Wi-Fi'ya bağlıysa VM host'unuzu ARP/port taramasıyla **görür ve hedefleyebilir**.

**USB passthrough** modda adaptör host'tan tamamen kopar ve VM'in kendi sürücüsüne
bağlanır. Host'un ağ yığını devreden çıkar, VM fiziksel olarak ayrı bir radyodan
kendi ağına çıkar. Bunun bedeli USB denetleyicisinin açık kalmasıdır (VirtualBox
USB emülasyonu da bir saldırı yüzeyidir) ve guest içinde adaptörün sürücüsü
gerekir — Kali/Ubuntu çoğu yaygın çipseti tanır.

> VirtualBox 7.1'den itibaren USB 2.0/3.0 desteği base pakette. **Extension Pack
> gerekmez.**

### Bridged kullanacaksanız — kritik uyarı

Araç, seçtiğiniz adaptörün host üzerinde aktif olup olmadığını kontrol eder ve
aynı L2 segmentine düşüyorsanız uyarır. Gerçek izolasyon için harici adaptörü
**host'unuzun bağlı olmadığı ayrı bir ağa** bağlayın — örneğin telefon hotspot'u.
Aksi halde "harici adaptör kullanıyorum" hissi yanıltıcıdır: aynı ağdaysanız
izolasyon yoktur.

---

## Uygulanan izolasyon ayarları

### Host ↔ Guest veri kanalları (kapatılır)

| Ayar | VBoxManage |
|------|-----------|
| Pano paylaşımı | `--clipboard-mode disabled` |
| Pano dosya transferi | `--clipboard-file-transfers disabled` |
| Sürükle-bırak | `--drag-and-drop disabled` |
| Paylaşılan klasörler | mevcut olanların tamamı `sharedfolder remove` ile silinir |
| Host saat senkronizasyonu | `setextradata .../GetHostTimeDisabled 1` |

### Saldırı yüzeyi azaltma

| Ayar | VBoxManage | Neden |
|------|-----------|-------|
| 3D hızlandırma | `--accelerate-3d off` | VirtualBox'ta en çok VM-escape CVE'si çıkan bileşen |
| Ses | `--audio-enabled off`, `--audio-driver none` | gereksiz emüle cihaz |
| Uzak masaüstü | `--vrde off` | dinleyen ağ servisi |
| İç içe sanallaştırma | `--nested-hw-virt off` | guest'e VT-x vermez |
| VM tracing | `--tracing-enabled off`, `--tracing-allow-vm-access off` | guest'ten host tracing arayüzü |
| Ekran kaydı | `--recording off` | host'a dosya yazan yol |
| Seri portlar | `--uart1..4 off` | host pipe/dosyaya bağlanabilir |
| Paralel portlar | `--lpt1..2 off` | aynı gerekçe |
| USB denetleyicileri | `--usb-ohci/-ehci/-xhci off`, `--usb-card-reader off` | `usbwifi` modu hariç hepsi kapalı |
| Paravirt arayüzü | `--paravirt-provider none` | host-guest paravirt kanalını kaldırır |

### Ağ

Her modda önce `nic1`–`nic8` tamamen sıfırlanır, sonra yalnızca istenen mod açılır.
Aktif NIC varsa `--nic-promisc<N> deny` (VM komşu trafiği dinleyemez) ve
`--mac-address<N> auto` (MAC host'la ilişkilendirilemez) uygulanır.

---

## Parametreler

| Parametre | Açıklama |
|-----------|----------|
| `-DryRun` | Hiçbir şey değiştirmez, çalıştırılacak komutları gösterir |
| `-VMName <ad>` | VM seçim menüsünü atlar |
| `-Network off\|intnet\|bridged\|usbwifi` | Ağ modu sorusunu atlar |
| `-Adapter <değer>` | `bridged` için adaptör adı, `usbwifi` için `VID:PID` (ör. `0BDA:8812`) |
| `-IntnetName <ad>` | Dahili ağ adı (varsayılan: `malware-lab`) |
| `-NoSnapshot` | Snapshot sorusunu atlar |
| `-Force` | VM çalışıyorsa sormadan kapatır |
| `-KeepParavirt` | Paravirt provider'ı değiştirmez (performans için) |
| `-KeepMac` | MAC adresini yenilemez |
| `-VBoxManagePath <yol>` | VBoxManage otomatik bulunamazsa |

Örnekler:

```powershell
# Tam izole, ağsız, snapshot'sız
.\VMIsolator.cmd -VMName "win10-lab" -Network off -NoSnapshot

# Harici USB kablosuz adaptörle izole internet
.\VMIsolator.cmd -VMName "win10-lab" -Network usbwifi -Adapter "0BDA:8812"

# İki VM'li dahili lab
.\VMIsolator.cmd -VMName "kurban"    -Network intnet -IntnetName lab1
.\VMIsolator.cmd -VMName "saldirgan" -Network intnet -IntnetName lab1
```

---

## Proje yapısı

Standart PowerShell modül düzeni: `VMIsolator.ps1` yalnızca giriş noktasıdır,
işin tamamı `src/` altındaki modülde yapılır.

```
VMIsolator.cmd                        # çift tıklanabilir başlatıcı (normal kullanıcı buradan başlar)
VMIsolator.ps1                        # giriş noktası — modülü yükler, Invoke-VMIsolation'ı çağırır
README.md
src/
├── VMIsolator.psd1                   # modül manifesti (sürüm, dışa açılan fonksiyonlar)
├── VMIsolator.psm1                   # yükleyici — Private/ ve Public/ dosyalarını dot-source eder
├── Public/
│   └── Invoke-VMIsolation.ps1        # ana akış: 6 adımı sırayla çalıştırır
└── Private/
    ├── UI.ps1                        # konsol çıktı yardımcıları
    ├── VBoxCli.ps1                   # VBoxManage çağrı katmanı (Read/Write/Set-Control)
    ├── VMInventory.ps1               # VM listesi ve ayarlarının okunması
    ├── HostDevices.ps1               # host ağ adaptörleri, USB cihazları, subnet hesabı
    ├── Prompts.ps1                   # etkileşimli girdi okuma
    ├── Select-TargetVM.ps1           # ADIM 1 — VM seçimi
    ├── Confirm-PowerState.ps1        # ADIM 2 — güç durumu
    ├── Resolve-NetworkPlan.ps1       # ADIM 3 — ağ modu ve adaptör seçimi
    ├── Set-IsolationControl.ps1      # ADIM 4 — izolasyon ayarları
    ├── Set-NetworkMode.ps1           # ADIM 4b — ağ yapılandırması
    ├── Test-IsolationState.ps1       # ADIM 5 — doğrulama
    ├── New-CleanSnapshot.ps1         # ADIM 6 — snapshot
    └── Write-IsolationSummary.ps1    # kapanış özeti ve kalan riskler
```

Yalnızca `Invoke-VMIsolation` dışa açılır; `Private/` altındaki her şey modül
içinde kalır. Modülü doğrudan da kullanabilirsiniz:

```powershell
Import-Module .\src\VMIsolator.psd1
Invoke-VMIsolation -VMName "win10-lab" -Network off
Get-Help Invoke-VMIsolation -Full
```

---

## Önerilen analiz iş akışı

1. `VMIsolator.cmd` (çift tıkla) → VM'i seç → izolasyon modunu seç
2. **Guest Additions'ı guest içinden kaldır** (araç bunu host'tan yapamaz —
   kurulu kaldığı sürece host-guest kanalı açık kalır)
3. Snapshot al (araç sonunda teklif eder)
4. Zararlıyı çalıştır, analiz et
5. Snapshot'a geri dön:
   ```powershell
   VBoxManage snapshot "VM-adi" restore "clean-isolated-YYYYMMDD-HHMMSS"
   ```

---

## Aracın çözemediği riskler

- **Guest Additions**: guest içinde kuruluysa host-guest kanalı açık kalır. Elle kaldırın.
- **Disk dosyaları**: VDI ve snapshot'lar host diskinde durur. Disk şifrelemesi kullanın.
- **VirtualBox sürümü**: VM-escape yamaları buradan gelir; güncel tutun.
- **`usbwifi` modunda** USB denetleyicisi açıktır ve adaptör VM'deyken host onu kullanamaz.
- **`bridged` modunda** host sürücü yığını trafik yolundadır — yukarıdaki kritik uyarıya bakın.
- VirtualBox, KVM/Xen gibi hipervizörlere kıyasla daha geniş bir emülasyon yüzeyine
  sahiptir. Gerçekten yüksek riskli örnekler için ayrı fiziksel donanım (air-gap)
  hâlâ en güvenli seçenektir.

---

## Geri alma

Araç ayarları geri almaz. En pratik yol, izolasyondan **önce** alınmış bir
snapshot'a dönmektir. Tek tek geri almak isterseniz:

```powershell
VBoxManage modifyvm "VM-adi" --clipboard-mode bidirectional
VBoxManage modifyvm "VM-adi" --drag-and-drop bidirectional
VBoxManage modifyvm "VM-adi" --paravirt-provider default
VBoxManage modifyvm "VM-adi" --nic1 nat
```
# viem
