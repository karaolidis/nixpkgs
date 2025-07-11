{
  lib,
  buildPythonPackage,
  fetchPypi,
  pythonOlder,
  atpublic,
  pdm-pep517,
  pytestCheckHook,
  pytest-cov-stub,
  sybil,
}:

buildPythonPackage rec {
  pname = "flufl-i18n";
  version = "4.1.1";
  pyproject = true;

  disabled = pythonOlder "3.7";

  src = fetchPypi {
    pname = "flufl.i18n";
    inherit version;
    hash = "sha256-wKz6aggkJ9YBJ+o75XjC4Ddnn+Zi9hlYDnliwTc7DNs=";
  };

  nativeBuildInputs = [ pdm-pep517 ];

  propagatedBuildInputs = [ atpublic ];

  pythonImportsCheck = [ "flufl.i18n" ];

  nativeCheckInputs = [
    pytestCheckHook
    pytest-cov-stub
    sybil
  ];

  pythonNamespaces = [ "flufl" ];

  meta = with lib; {
    description = "High level API for internationalizing Python libraries and applications";
    homepage = "https://gitlab.com/warsaw/flufl.i18n";
    changelog = "https://gitlab.com/warsaw/flufl.i18n/-/raw/${version}/docs/NEWS.rst";
    license = licenses.asl20;
    maintainers = [ ];
  };
}
