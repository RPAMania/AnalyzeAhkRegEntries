#include RegResult.ahk

class RegWarning extends RegResult
{
  __New(params*)
  {
    super.__New(params*)
  }

  Message
  {
    get
    {
      if (this.value.found !== this.value.expected)
      {
        return Format(RegWarning.Template.VALUE_CHANGED, 
            this.branch.name,
            this.value.isDefault
                ? Format(RegWarning.Template.DEFAULT_VALUE_TEXT, " '" this.value.found "'")
                : Format(RegWarning.Template.NONDEFAULT_VALUE_TEXT, 
                    Format(RegWarning.Template.TEXT_PLACEHOLDER, this.value.found) " ", 
                    this.value.name), 
            this.value.expected)
      }
    }
  }
}