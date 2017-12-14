version (D_Version2)
    mixin("extern(C) int printf(const char*, ...);");
else
    mixin("extern(C) int printf(char*, ...);");

void main()
{
    printf("Yes, we can run a D program!\n".ptr);
}
