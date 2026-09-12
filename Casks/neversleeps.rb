# Cask do Homebrew para o neversleeps (tap pessoal).
#
# Como usar (usuario):
#   brew tap philipecomputacao/neversleeps https://github.com/philipecomputacao/neversleeps
#   brew install --cask neversleeps
#
# Como publicar (mantenedor): publicar.sh atualiza version e sha256 aqui a cada
# release; depois, commite este arquivo. Ele precisa estar em Casks/ na raiz do
# repositorio para o `brew tap` acima funcionar.
#
# Sem Developer ID o Homebrew instala, mas o Gatekeeper ainda pede "botao
# direito -> Abrir" na primeira vez (o caveat abaixo avisa).
cask "neversleeps" do
  version "1.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/philipecomputacao/neversleeps/releases/download/v#{version}/neversleeps-#{version}.zip"
  name "neversleeps"
  desc "Keeps the Mac working with the lid closed (menu bar toggle for pmset disablesleep)"
  homepage "https://github.com/philipecomputacao/neversleeps"

  depends_on macos: ">= :sonoma"

  app "neversleeps.app"

  uninstall quit: "me.lpdigital.neversleeps"
  zap trash: "~/Library/Preferences/me.lpdigital.neversleeps.plist"

  caveats <<~EOS
    O app ainda nao e notarizado pela Apple. Na primeira abertura:
    clique com o botao direito em neversleeps.app -> Abrir (uma vez).

    The app is not yet notarized by Apple. On first launch:
    right-click neversleeps.app -> Open (once).
  EOS
end
