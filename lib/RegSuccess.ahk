#Include RegResult.ahk

class RegSuccess extends RegResult
{
  __New(params*)
  {
    super.__New(params*)
  }

  Message
  {
    get
    {
      return ""
    }
  }
}