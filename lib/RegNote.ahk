#Include RegResult.ahk

class RegNote extends RegResult
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
        return Format(RegNote.Template.AHK2_REMOVED_VALUE, this.branch.name)
      }

      return Format(RegNote.Template.AHK2_OVERWRITTEN_VALUE, this.branch.name, 
          this.value.expected)
    }
  }
}