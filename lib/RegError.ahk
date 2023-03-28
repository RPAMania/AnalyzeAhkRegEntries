#Include RegResult.ahk

class RegError extends RegResult
{
  __New(params*)
  {
    super.__New(params*)
  }

  Message
  {
    get
    {
      if (this.branch.isMissing)
      {
        return Format(RegError.Template.BRANCH_MISSING, this.branch.name)
      }
      
      if (this.value.isDefault)
      {
        valueTypeSpecifierText := Format(RegError.Template.DEFAULT_VALUE_TEXT, 
            this.value.isMissing ? "" : " '" this.value.found "'")
      }
      else
      {
        actualValue := ""
        
        if (!this.value.isMissing)
        {
          actualValue := Format(RegError.Template.TEXT_PLACEHOLDER, this.value.found) " "
        }

        valueTypeSpecifierText := Format(RegError.Template.NONDEFAULT_VALUE_TEXT, 
            actualValue, this.value.name) 
      }

      if (this.value.isMissing)
      {
        return Format(RegError.Template.VALUE_MISSING, this.branch.name, 
            valueTypeSpecifierText, this.value.name)
      }
      else if (this.value.found !== this.value.expected)
      {
        return Format(RegError.Template.VALUE_MISMATCH, this.branch.name, 
            valueTypeSpecifierText, this.value.expected)
      }

      throw Error("Error message not specified.")
    }
  }
}