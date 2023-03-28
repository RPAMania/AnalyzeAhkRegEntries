class RegResult
{
  static Template := 
  {
    DEFAULT_VALUE_TEXT: "current default value{1}",
    NONDEFAULT_VALUE_TEXT: "value {1}by the name '{2}'",
    TEXT_PLACEHOLDER: "'{1}'",

    AHK2_REMOVED_VALUE: "The entry '{1}' has been removed by AHK2 installer",
    AHK2_OVERWRITTEN_VALUE: "The value '{2}' of the registry branch '{1}' has been overwritten by AHK2 installer",
    
    BRANCH_MISSING: "The registry branch '{1}' is missing.",
    VALUE_MISSING: "The {2} of the registry branch '{1}' is missing.",
    ; VALUE_MISSING: "The {2} for the key '{3}' of the registry branch '{1}' is missing.",
    VALUE_MISMATCH: "The {2} of the registry branch '{1}' " .
    ; VALUE_MISMATCH: "The {2} for the key '{3}' of the registry branch '{1}' " .
        ; "does not match the expected value '{4}'.",
        "does not match the expected value '{3}'.",
    VALUE_CHANGED: "The {2} of the registry branch '{1}' " .
    ; VALUE_CHANGED: "The {2} for the key '{3}' of the registry branch '{1}' " .
        ; "has been modified from the original value '{4}'."
        "has been modified from the original value '{3}'."
  }

  branch :=
  {
    name: "",
    isMissing: false
  }

  value :=
  {
    name: "",
    isMissing: false,
    found: "",
    expected: "",
    isDefault: true
  }

  /**
   * Constructor
   * @param {string} branchName 
   * @param {boolean} isBranchMissing 
   * @param {string} valueName
   * @param {boolean} isValueMissing
   * @param {string} value 
   * @param {string} valueExpected  
   * @param {boolean} isDefaultValue
   * @returns {RegErrorMessage}
   */
  __New(branchName, isBranchMissing, valueName := "", isValueMissing := true, value := "", valueExpected := "", isDefaultValue := true)
  {
    this.branch.name := branchName
    this.branch.isMissing := isBranchMissing
    this.value.isMissing := isValueMissing
    this.value.name := valueName != "" || isValueMissing ? valueName : "(Default)"
    this.value.found := value
    this.value.expected := valueExpected
    this.value.isDefault := isDefaultValue
  }

  Message
  {
    get
    {
      throw Error("Not implemented", -2, "Message property")
    }
  }
}